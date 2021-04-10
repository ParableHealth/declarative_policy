# Configuration

This library is generally configured by writing policies that match
the look-up rules for domain objects (see: [defining policies](./defining-policies.md)).

## Configuration blocks

This library can be configured using `DeclarativePolicy.configure` and
`DeclarativePolicy.configure!`. Both methods take a block, and they differ only
in that `.configure!` ensures that the configuration is pristine, and
discards any previous configuration, and `configure` can be called multiple
times.

## Handling `nil` values

By default, all permission checks on `nil` values are denied. This is
controlled by `DeclarativePolicy::NilPolicy`, which is implemented as:

```ruby
module DeclarativePolicy
  class NilPolicy < DeclarativePolicy::Base
    rule { default }.prevent_all
  end
end
```

If you want to handle `nil` values differently, then you can define your
own `nil` policy, and configure it to be used in a configuration block:

```ruby
DeclarativePolicy.configure do
  nil_policy MyNilPolicy
end
```

## Named policies

Normally policies are determined by looking up matching policy definitions
based on the class of the value. `Symbol` values are treated specially, and
these define **named policies**.

To define a named policy, use a configuration block:

```ruby
DeclarativePolicy.configure do
  named_policy :global, MyGlobalPolicy
end
```

Then it can be used by passing the `:global` symbol as the value in a permission
check:

```
policy = DeclarativePolicy.policy_for(the_user, :global)
policy.allowed?(:some_ability)
```

This can be useful where there is no object of the permission check (that is,
the predicate is **intransitive**). An example might be `:can_log_in`, where
there is no suitable object, and the identity of the user is fully sufficient to
determine the permission check.

Using `:global` is a convention, but any policy name can be used.

## Name transformation

By default, policy classes are expected to be named for the domain classes, with
a `Policy` suffix. So a domain class of `Foo` would resolve to a `FooPolicy`.

This logic can be customized by specifying the `name_transformation` rule. To
instead have all policies be placed in a `Policies` namespace, so that `Foo`
would have its policy at `Policies::Foo`, we can configure that with:

```ruby
DeclarativePolicy.configure do
  name_transformation { |name| "Policies::#{name}" }
end
```
