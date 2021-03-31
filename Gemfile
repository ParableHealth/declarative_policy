# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in declarative-policy.gemspec
gemspec

gem 'activesupport', '>= 6.0'
gem 'rake', '~> 12.0'
gem 'rubocop', require: false

group :test do
  gem 'rspec', '~> 3.0'
  gem 'rspec-parameterized', require: false
  gem 'pry-byebug'
end

group :development, :test do
  gem 'gitlab-styles', '~> 6.1.0', require: false
end

group :development, :test, :danger do
  gem 'gitlab-dangerfiles', '~> 1.1.0', require: false
end
