# frozen_string_literal: true

module DeclarativePolicy
  class Base
    # A map of ability => list of rules together with :enable
    # or :prevent actions. Used to look up which rules apply to
    # a given ability. See Base.ability_map
    class AbilityMap
      attr_reader :map

      def initialize(map = {})
        @map = map
      end

      # This merge behavior is different than regular hashes - if both
      # share a key, the values at that key are concatenated, rather than
      # overridden.
      def merge(other)
        conflict_proc = proc { |_key, my_val, other_val| my_val + other_val }
        AbilityMap.new(@map.merge(other.map, &conflict_proc))
      end

      def actions(key)
        @map[key] ||= []
      end

      def enable(key, rule)
        actions(key) << [:enable, rule]
      end

      def prevent(key, rule)
        actions(key) << [:prevent, rule]
      end
    end

    class Options
      def initialize
        @hash = {}
      end

      def []=(key, value)
        @hash[key.to_sym] = value
      end

      def [](key)
        @hash[key.to_sym]
      end

      def to_h
        @hash
      end
    end

    class << self
      # The `own_ability_map` vs `ability_map` distinction is used so that
      # the data structure is properly inherited - with subclasses recursively
      # merging their parent class.
      #
      # This pattern is also used for conditions, global_actions, and delegations.
      def ability_map
        if self == Base
          own_ability_map
        else
          superclass.ability_map.merge(own_ability_map)
        end
      end

      def own_ability_map
        @own_ability_map ||= AbilityMap.new
      end

      # an inheritable map of conditions, by name
      def conditions
        if self == Base
          own_conditions
        else
          superclass.conditions.merge(own_conditions)
        end
      end

      def own_conditions
        @own_conditions ||= {}
      end

      # a list of global actions, generated by `prevent_all`. these aren't
      # stored in `ability_map` because they aren't indexed by a particular
      # ability.
      def global_actions
        if self == Base
          own_global_actions
        else
          superclass.global_actions + own_global_actions
        end
      end

      def own_global_actions
        @own_global_actions ||= []
      end

      # an inheritable map of delegations, indexed by name (which may be
      # autogenerated)
      def delegations
        if self == Base
          own_delegations
        else
          superclass.delegations.merge(own_delegations)
        end
      end

      def own_delegations
        @own_delegations ||= {}
      end

      # all the [rule, action] pairs that apply to a particular ability.
      # we combine the specific ones looked up in ability_map with the global
      # ones.
      def configuration_for(ability)
        ability_map.actions(ability) + global_actions
      end

      ### declaration methods ###

      def delegate(name = nil, &delegation_block)
        if name.nil?
          @delegate_name_counter ||= 0
          @delegate_name_counter += 1
          name = :"anonymous_#{@delegate_name_counter}"
        end

        name = name.to_sym

        # rubocop: disable GitlabSecurity/PublicSend
        delegation_block = proc { @subject.__send__(name) } if delegation_block.nil?
        # rubocop: enable GitlabSecurity/PublicSend

        own_delegations[name] = delegation_block
      end

      # Declare that the given abilities should not be read from delegates.
      #
      # This is useful if you have an ability that you want to define
      # differently in a policy than in a delegated policy, but still want to
      # delegate all other abilities.
      #
      # example:
      #
      #   delegate { @subect.parent }
      #
      #   overrides :drive_car, :watch_tv
      #
      def overrides(*names)
        @overrides ||= [].to_set
        @overrides.merge(names)
      end

      # Declares a rule, constructed using RuleDsl, and returns
      # a PolicyDsl which is used for registering the rule with
      # this class. PolicyDsl will call back into Base.enable_when,
      # Base.prevent_when, and Base.prevent_all_when.
      def rule(&block)
        rule = RuleDsl.new(self).instance_eval(&block)
        PolicyDsl.new(self, rule)
      end

      # A hash in which to store calls to `desc` and `with_scope`, etc.
      def last_options
        @last_options ||= Options.new
      end

      def with_options(opts = {})
        last_options.to_h.merge!(opts.to_h)
      end

      # Declare a description for the following condition. Currently unused,
      # but opens the potential for explaining to users why they were or were
      # not able to do something.
      def desc(description)
        with_options description: description
      end

      # Declare a scope for the following condition.
      def with_scope(scope)
        with_options scope: scope
      end

      # Declare a score for the following condition.
      def with_score(score)
        with_options score: score
      end

      # Declares a condition. It gets stored in `own_conditions`, and generates
      # a query method based on the condition's name.
      def condition(condition_name, opts = {}, &value)
        condition_name = condition_name.to_sym

        condition = Condition.new(condition_name, condition_options(opts), &value)

        own_conditions[condition_name] = condition

        define_method(:"#{condition_name}?") { condition(condition_name).pass? }
      end

      # These next three methods are mainly called from PolicyDsl,
      # and are responsible for "inverting" the relationship between
      # an ability and a rule. We store in `ability_map` a map of
      # abilities to rules that affect them, together with a
      # symbol indicating :prevent or :enable.
      def enable_when(abilities, rule)
        abilities.each { |a| own_ability_map.enable(a, rule) }
      end

      def prevent_when(abilities, rule)
        abilities.each { |a| own_ability_map.prevent(a, rule) }
      end

      # we store global prevents (from `prevent_all`) separately,
      # so that they can be combined into every decision made.
      def prevent_all_when(rule)
        own_global_actions << [:prevent, rule]
      end

      private

      # retrieve and zero out the previously set options (used in .condition)
      def condition_options(opts)
        # The context_key distinguishes two conditions of the same name.
        # For anonymous classes, use object_id.
        opts[:context_key] ||= (name || object_id)
        with_options(opts).tap { @last_options = nil }
      end
    end

    # A policy object contains a specific user and subject on which
    # to compute abilities. For this reason it's sometimes called
    # "context" within the framework.
    #
    # It also stores a reference to the cache, so it can be used
    # to cache computations by e.g. ManifestCondition.
    attr_reader :user, :subject

    def initialize(user, subject, opts = {})
      @user = user
      @subject = subject
      @cache = opts[:cache] || {}
    end

    # helper for checking abilities on this and other subjects
    # for the current user.
    def can?(ability, new_subject = :_self)
      return allowed?(ability) if new_subject == :_self

      policy_for(new_subject).allowed?(ability)
    end

    # This is the main entry point for permission checks. It constructs
    # or looks up a Runner for the given ability and asks it if it passes.
    def allowed?(*abilities)
      abilities.all? { |a| runner(a).pass? }
    end

    # The inverse of #allowed?, used mainly in specs.
    def disallowed?(*abilities)
      abilities.all? { |a| !runner(a).pass? }
    end

    # computes the given ability and prints a helpful debugging output
    # showing which
    def debug(ability, *args)
      runner(ability).debug(*args)
    end

    desc 'Unknown user'
    condition(:anonymous, scope: :user, score: 0) { @user.nil? }

    desc 'By default'
    condition(:default, scope: :global, score: 0) { true }

    def repr
      "(#{identify_user} : #{identify_subject})"
    end

    def identify_user
      return '<anonymous>' unless @user

      @user.to_reference
    rescue NoMethodError
      "<#{@user.class}: #{@user.object_id}>"
    end

    def identify_subject
      if @subject.respond_to?(:id)
        "#{@subject.class.name}/#{@subject.id}"
      else
        @subject.inspect
      end
    end

    def inspect
      "#<#{self.class.name} #{repr}>"
    end

    # returns a Runner for the given ability, capable of computing whether
    # the ability is allowed. Runners are cached on the policy (which itself
    # is cached on @cache), and caches its result. This is how we perform caching
    # at the ability level.
    def runner(ability)
      ability = ability.to_sym
      @runners ||= {}
      @runners[ability] ||=
        begin
          own_runner = Runner.new(own_steps(ability))
          if self.class.overrides.include?(ability)
            own_runner
          else
            delegated_runners = delegated_policies.values.compact.map { |p| p.runner(ability) }
            delegated_runners.reduce(own_runner, &:merge_runner)
          end
        end
    end

    # Helpers for caching. Used by ManifestCondition in performing condition
    # computation.
    #
    # NOTE we can't use ||= here because the value might be the
    # boolean `false`
    def cache(key)
      return @cache[key] if cached?(key)

      @cache[key] = yield
    end

    def cached?(key)
      !@cache[key].nil?
    end

    # returns a ManifestCondition capable of computing itself. The computation
    # will use our own @cache.
    def condition(name)
      name = name.to_sym
      @_conditions ||= {}
      @_conditions[name] ||=
        begin
          raise "invalid condition #{name}" unless self.class.conditions.key?(name)

          ManifestCondition.new(self.class.conditions[name], self)
        end
    end

    # used in specs - returns true if there is no possible way for any action
    # to be allowed, determined only by the global :prevent_all rules.
    def banned?
      global_steps = self.class.global_actions.map { |(action, rule)| Step.new(self, rule, action) }
      !Runner.new(global_steps).pass?
    end

    # A list of other policies that we've delegated to (see `Base.delegate`)
    def delegated_policies
      @delegated_policies ||= self.class.delegations.transform_values do |block|
        new_subject = instance_eval(&block)

        # never delegate to nil, as that would immediately prevent_all
        next if new_subject.nil?

        policy_for(new_subject)
      end
    end

    def policy_for(other_subject)
      DeclarativePolicy.policy_for(@user, other_subject, cache: @cache)
    end

    protected

    # constructs steps that come from this policy and not from any delegations
    def own_steps(ability)
      rules = self.class.configuration_for(ability)
      rules.map { |(action, rule)| Step.new(self, rule, action) }
    end
  end
end
