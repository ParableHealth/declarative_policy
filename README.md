# `DeclarativePolicy`: A Declarative Authorization Library

This library provides a DSL for writing authorization policies.

It can be used to separate logic from permissions, and has been
used at scale in production at [GitLab.com](https://gitlab.com).

The original author of this library is [Jeanine Adkisson](http://jneen.net),
and copyright is held by GitLab.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'declarative_policy'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install declarative_policy

## Usage

TODO: Write usage instructions here

## Development

After checking out the repository, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://gitlab.com/gitlab-org/declarative-policy. This project is intended to be
a safe, welcoming space for collaboration, and contributors are expected to
adhere to the [GitLab code of conduct](https://about.gitlab.com/community/contribute/code-of-conduct/).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the `DeclarativePolicy` project's codebase, issue
trackers, chat rooms and mailing lists is expected to follow
the [code of conduct](https://github.com/[USERNAME]/declarative-policy/blob/master/CODE_OF_CONDUCT.md).
