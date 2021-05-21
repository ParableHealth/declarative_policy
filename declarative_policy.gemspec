# frozen_string_literal: true

require_relative 'lib/declarative_policy/version'

Gem::Specification.new do |spec|
  spec.name          = 'declarative_policy'
  spec.version       = DeclarativePolicy::VERSION
  spec.authors       = ['Jeanine Adkisson', 'Alexis Kalderimis']
  spec.email         = ['akalderimis@gitlab.com']

  spec.summary       = 'An authorization library with a focus on declarative policy definitions.'
  spec.description   = <<~DESC
    This library provides an authorization framework with a declarative DSL

    With this library, you can write permission policies that are separate
    from business logic.

    This library is in production use at GitLab.com
  DESC
  spec.homepage      = 'https://gitlab.com/gitlab-org/declarative-policy'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://gitlab.com/gitlab-org/declarative-policy'
  spec.metadata['changelog_uri'] = 'https://gitlab.com/gitlab-org/declarative-policy/-/blobs/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
