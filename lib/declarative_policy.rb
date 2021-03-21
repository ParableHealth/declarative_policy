# frozen_string_literal: true

require 'active_support/dependencies'
require 'active_support/core_ext'

require_relative 'declarative_policy/cache'
require_relative 'declarative_policy/condition'
require_relative 'declarative_policy/delegate_dsl'
require_relative 'declarative_policy/policy_dsl'
require_relative 'declarative_policy/rule_dsl'
require_relative 'declarative_policy/preferred_scope'
require_relative 'declarative_policy/rule'
require_relative 'declarative_policy/runner'
require_relative 'declarative_policy/step'
require_relative 'declarative_policy/base'

# DeclarativePolicy: A DSL based authorization framework
module DeclarativePolicy
  extend PreferredScope

  CLASS_CACHE_MUTEX = Mutex.new
  CLASS_CACHE_IVAR = :@__DeclarativePolicy_CLASS_CACHE

  class << self
    def policy_for(user, subject, opts = {})
      cache = opts[:cache] || {}
      key = Cache.policy_key(user, subject)

      cache[key] ||=
        # to avoid deadlocks in multi-threaded environment when
        # autoloading is enabled, we allow concurrent loads,
        # https://gitlab.com/gitlab-org/gitlab-foss/issues/48263
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          class_for(subject).new(user, subject, opts)
        end
    end

    def class_for(subject)
      return GlobalPolicy if subject == :global
      return NilPolicy if subject.nil?

      subject = find_delegate(subject)

      policy_class = class_for_class(subject.class)
      raise "no policy for #{subject.class.name}" if policy_class.nil?

      policy_class
    end

    def policy?(subject)
      !class_for_class(subject.class).nil?
    end
    alias_method :has_policy?, :policy?

    private

    # This method is heavily cached because there are a lot of anonymous
    # modules in play in a typical rails app, and #name performs quite
    # slowly for anonymous classes and modules.
    #
    # See https://bugs.ruby-lang.org/issues/11119
    #
    # if the above bug is resolved, this caching could likely be removed.
    def class_for_class(subject_class)
      unless subject_class.instance_variable_defined?(CLASS_CACHE_IVAR)
        CLASS_CACHE_MUTEX.synchronize do
          # re-check in case of a race
          break if subject_class.instance_variable_defined?(CLASS_CACHE_IVAR)

          policy_class = compute_class_for_class(subject_class)
          subject_class.instance_variable_set(CLASS_CACHE_IVAR, policy_class)
        end
      end

      subject_class.instance_variable_get(CLASS_CACHE_IVAR)
    end

    def compute_class_for_class(subject_class)
      return subject_class.declarative_policy_class.constantize if subject_class.respond_to?(:declarative_policy_class)

      subject_class.ancestors.each do |klass|
        name = klass.name
        klass = policy_class(name)

        return klass if klass
      end

      nil
    end

    def policy_class(name)
      return unless name

      policy_class = "#{name}Policy".constantize

      return policy_class if policy_class < Base
    rescue NameError
      nil
    end

    def find_delegate(subject)
      seen = Set.new

      while subject.respond_to?(:declarative_policy_delegate)
        raise ArgumentError, 'circular delegations' if seen.include?(subject.object_id)

        seen << subject.object_id
        subject = subject.declarative_policy_delegate
      end

      subject
    end
  end
end
