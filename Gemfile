# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in declarative-policy.gemspec
gemspec

group :test do
  gem 'rspec', '~> 3.10'
  gem 'rspec-parameterized', require: false
  gem 'pry-byebug', platforms: [:ruby]
end

group :development, :test do
  gem 'gitlab-styles', '~> 6.1.0', require: false, platforms: [:ruby]
  gem 'rake', '~> 12.0'
  gem 'benchmark', require: false
  gem 'rubocop', require: false
end

group :development, :test, :danger do
  gem 'gitlab-dangerfiles', '~> 1.1.0', require: false, platforms: [:ruby]
end
