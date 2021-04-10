# frozen_string_literal: true

module DeclarativePolicy
  class Configuration
    ConfigurationError = Class.new(StandardError)

    def initialize
      @named_policies = {}
    end

    def named_policy(name, policy = nil)
      @named_policies[name] = policy if policy

      @named_policies[name] || raise(ConfigurationError, "No #{name} policy configured")
    end

    def nil_policy(policy = nil)
      @nil_policy = policy if policy

      @nil_policy || ::DeclarativePolicy::NilPolicy
    end
  end
end
