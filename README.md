# `DeclarativePolicy`: A Declarative Authorization Library

[![Gem Version](https://badge.fury.io/rb/declarative_policy.svg)](https://badge.fury.io/rb/declarative_policy)

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


The core abstraction of this library is a `Policy`. Policies combine:

- **facts** (called `conditions`) about the state of the world
- **judgements** about these facts (called `rules`)

This library exists to determine the truth value of statements of the form:

```
Subject Predicate [Object]
```

For example:

- `user :is_alive`
- `user :can_drive car`
- `user :can_sell car`

It does this by letting us associate a `Policy` (a set of rules about which
statements are true) with the objects of the sentences. A statement is
considered to hold if no rule `prevents` it, and at least one rule `enables` it.

For example, imagine we have a data model containing vehicles and users, and we
want to know if a user can drive a vehicle. We need a `VehiclePolicy`:

```ruby
class VehiclePolicy < DeclarativePolicy::Base
  # relevant facts
  condition(:owns) { @subject.owner == @user }
  condition(:has_access_to) { @subject.owner.trusts?(@user) }
  condition(:old_enough_to_drive) { @user.age >= laws.minimum_age }
  condition(:has_driving_license) { @user.driving_license&.valid? }
  # expensive rules can have 'score'. Higher scores are 'more expensive' to calculate
  condition(:owns, score: 0) { @subject.owner == @user }
  condition(:has_access_to, score: 3) { @subject.owner.trusts?(@user) }
  condition(:intoxicated, score: 5) { @user.blood_alcohol > laws.max_blood_alcohol }
  
  # conclusions we can draw:
  rule { owns }.enable :drive_vehicle
  rule { has_access_to }.enable :drive_vehicle
  rule { ~old_enough_to_drive }.prevent :drive_vehicle
  rule { intoxicated }.prevent :drive_vehicle
  rule { ~has_driving_license }.prevent :drive_vehicle
  
  # we can use methods to abstract common logic
  def laws
    @subject.registration.country.driving_laws
  end
end
```

A few points to note: we could have written this as one big rule
(`(owns | has_access_to) & old_enough_to_drive & ~intoxicated & has_driving_license`)
but we can see some of the features that make declarative policies scalable for
large systems: rules can be broken up into small elements, and composed into
larger rules. New conditions and rules can be added at any time.

What is more difficult to see is that many performance optimizations are handled
for us transparently:

- more expensive conditions are called later
- we automatically get the desired groupings (evaluate all conditions that might
  prevent an action, but stop once we have at least one call to enable).
- intermediate values are cached.
- policies support inheritance and delegation, meaning authorization logic
  remains DRY.

In short this library aims to be declarative: we declare the rules that are
important, and the library arranges how to evaluate them.

Caching is a particularly valuable feature of policies. If we add new rules
about selling a vehicle, for example:

```ruby
rule { owns }.enable :sell_vehicle
```

Then the fact of ownership can be shared between different calls to the policy,
saving database calls and other expensive IO operations.

### Evaluating a policy:

We can check the determination of a policy with:

```ruby
cache = Session.current_session
policy = DeclarativePolicy.policy_for(user, car, cache: cache)
policy.can?(:drive_vehicle)
```

For more usage details, see the [documentation](doc).

## Development

After checking out the repository, run `bundle install` to install dependencies.
Then, run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and merge requests are welcome on GitLab at
https://gitlab.com/gitlab-org/declarative-policy. This project is intended to be
a safe, welcoming space for collaboration, and contributors are expected to
adhere to the [GitLab code of conduct](https://about.gitlab.com/community/contribute/code-of-conduct/).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the `DeclarativePolicy` project's codebase, issue
trackers, chat rooms and mailing lists is expected to follow
the [code of conduct](https://github.com/[USERNAME]/declarative-policy/blob/master/CODE_OF_CONDUCT.md).
