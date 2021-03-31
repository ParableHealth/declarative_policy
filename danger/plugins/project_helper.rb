# frozen_string_literal: true

module Danger
  # Common helper functions for our danger scripts. See Tooling::Danger::ProjectHelper
  # for more details
  class ProjectHelper < ::Danger::Plugin
    LOCAL_RULES ||= %w[
      changelog
      documentation
    ].freeze

    CI_ONLY_RULES ||= %w[
      roulette
    ].freeze

    MESSAGE_PREFIX = '==>'

    # First-match win, so be sure to put more specific regex at the top...
    # rubocop: disable Style/RegexpLiteral
    CATEGORIES = {
      %r{(\A|/)(
        \.gitlab/ci/frontend\.gitlab-ci\.yml
      )\z}x => %i[frontend engineering_productivity],
      %r{\A(\.gitlab-ci\.yml\z|\.gitlab/ci)} => :engineering_productivity,
      %r{\Alefthook.yml\z} => :engineering_productivity,
      %r{\A\.editorconfig\z} => :engineering_productivity,
      %r{Dangerfile\z} => :engineering_productivity,
      %r{\A(danger/|tooling/danger/)} => :engineering_productivity,
      %r{\A?scripts/} => :engineering_productivity,
      %r{\Atooling/} => :engineering_productivity,
      %r{(CODEOWNERS)} => :engineering_productivity,
      %r{\A(Gemfile|Gemfile.lock|Rakefile)\z} => :backend,
      %r{\A[A-Z_]+_VERSION\z} => :backend,
      %r{\A\.rubocop((_manual)?_todo)?\.yml\z} => :backend,
      # Files that don't fit into any category are marked with :none
      %r{\A(ee/)?changelogs/} => :none,
      # Fallbacks in case the above patterns miss anything
      %r{\.rb\z} => :backend,
      %r{(
        \.(md|txt)\z |
        \.markdownlint\.json
      )}x => :docs
    }.freeze
    # rubocop: enable Style/RegexpLiteral

    def changes_by_category
      helper.changes_by_category(CATEGORIES)
    end

    def changes
      helper.changes(CATEGORIES)
    end

    def rule_names
      helper.ci? ? LOCAL_RULES | CI_ONLY_RULES : LOCAL_RULES
    end

    def project_name
      'declarative-policy'
    end
  end
end
