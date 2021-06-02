# frozen_string_literal: true

require 'set'
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
require_relative 'declarative_policy/nil_policy'
require_relative 'declarative_policy/configuration'

# DeclarativePolicy: A DSL based authorization framework
module DeclarativePolicy
  extend PreferredScope

  class << self
    def policy_for(user, subject, opts = {})
      cache = opts[:cache] || {}
      key = Cache.policy_key(user, subject)

      cache[key] ||= class_for(subject).new(user, subject, opts)
    end

    def class_for(subject)
      return configuration.nil_policy if subject.nil?
      return configuration.named_policy(subject) if subject.is_a?(Symbol)

      subject = find_delegate(subject)

      policy_class = class_for_class(subject.class)
      raise "no policy for #{subject.class.name}" if policy_class.nil?

      policy_class
    end

    def configure(&block)
      configuration.instance_eval(&block)

      nil
    end

    # Reset configuration
    def configure!(&block)
      @configuration = DeclarativePolicy::Configuration.new
      configure(&block) if block
    end

    def policy?(subject)
      !class_for_class(subject.class).nil?
    end
    alias_method :has_policy?, :policy?

    private

    def configuration
      @configuration ||= DeclarativePolicy::Configuration.new
    end

    def class_for_class(subject_class)
      if subject_class.respond_to?(:declarative_policy_class)
        Object.const_get(subject_class.declarative_policy_class)
      else
        subject_class.ancestors.each do |klass|
          name = klass.name
          klass = policy_class(name)

          return klass if klass
        end

        nil
      end
    end

    def policy_class(name)
      clazz = configuration.policy_class(name)

      clazz if clazz && clazz < Base
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
