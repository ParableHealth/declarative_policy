# Defining policies

A policy is a set of conditions and rules for domain objects. They are defined
using a DSL, and mapped to domain objects by class name.

## Class name determines policy choice

If there is a domain class `Foo`, then we can link it to a policy by defining a
class `FooPolicy`. This class can be placed anywhere, as long as it is loaded
before the call to `DeclarativePolicy.policy_for`.

Our recommendation for large applications, such as Rails apps, is to add a new
top-level application directory: `app/policies`, and place all policy
definitions in there. If you have an `Invoice` model at `app/models/invoice.rb`,
then you would create an `InvoicePolicy` at `app/policies/invoice_policy.rb`.

## Invocation

We evaluate policies by instantiating them with `DeclarativePolicy::policy_for`,
and then evaluating them with `DeclarativePolicy::Base#allowed?`.

You may wish to define a method to abstract policy evaluation. Something like:

```ruby
def allowed?(user, ability, object)
  opts = { cache: Cache.current_cache } # re-using a cache between checks eliminates duplication of work
  policy = DeclarativePolicy.policy_for(user, object, opts)
  policy.allowed?(ability)
end
```

We will assume the presence of such a method below.

## Defining rules in the DSL

The DSL has two primary parts: defining **conditions** and **rules**.

For example, imagine we have a data model containing vehicles and users, and we
want to know if a user can drive a vehicle. We need a `VehiclePolicy`:

```ruby
class VehiclePolicy < DeclarativePolicy::Base
  # conditions go here by convention
  
  # rules go here by convention
  
  # helper methods go last
end
```

### Conditions

Conditions are facts about the state of the system.

They have access to two elements of the proposition:

- `@user` - the representation of a user in your system: the *subject* of the proposition.
  `user` in `allowed?(user, ability, object)`. `@user` may be `nil`, which means
  that the current user is anonymous (for example this may reflect an
  unauthenticated request in your system).
- `@subject` - any domain object that has an associated policy: the *object* of
  the predicate of the proposition. `object` in `allowed?(user, ability, object)`.
  `@subject` is never `nil`. See [handling `nil` values](./configuration.md#handling-nil-values)
  for details of how to apply policies to `nil` values.
  

They are defined as `condition(name, **options, &block)`, where the block is
evaluated in the context of an instance of the policy.

For example:

```ruby
condition(:owns) { @subject.owner == @user }
condition(:has_access_to) { @subject.owner.trusts?(@user) }
condition(:old_enough_to_drive) { @user.age >= laws.minimum_age }
condition(:has_driving_license) { @user.driving_license&.valid? }
condition(:intoxicated, score: 5) { @user.blood_alcohol > laws.max_blood_alcohol }
condition(:has_access_to, score: 3) { @subject.owner.trusts?(@user) }
```

These can be defined in any order, but we consider it best practice to define
conditions at the top of the file.

Conditions may call methods of the policy class, which can be helpful for
memoizing some intermediate state:

```ruby
condition(:full_license) { license.full? }
condition(:learner_license) { license.learner? }
condition(:hgv_license) { license.heavy_goods? }

def license
  @license ||= Licenses.by_country(@user.country_of_residence).for_user(@user)
end
```

Conditions are evaluated at most once, and their values are automatically
memoized and cached (see [caching](./caching.md) for more detail).

If you want to perform I/O (such as database access) or expensive computations,
place this access in a condition.

### Rules

Rules are conclusions we can draw based on the facts:

```ruby
rule { owns }.enable :drive_vehicle
rule { has_access_to }.enable :drive_vehicle
rule { ~old_enough_to_drive }.prevent :drive_vehicle
rule { intoxicated | ~has_driving_license }.prevent :drive_vehicle
```

Rules are combined such that each ability must be enabled at least once, and not
prevented in order to be permitted. So `enable` calls are implicitly combined
with `ANY`, and `prevent` calls are implicitly combined with `ALL`.

A set of conclusions can be defined for a single condition:

```ruby
rule { old_enough_to_drive }.policy do
  enable :drive_vehicle
  enable :vote
end
```

Rule blocks do not have access to the internal state of the policy, and cannot
access the `@user` or `@subject`, or any methods on the policy instance. You
should not perform I/O in a rule. They exist solely to define the logical rules
of implication and combination between conditions.

The available operations inside a rule block are:

- Bare words to refer to conditions in the policy, or on any delegate.
  For example `owns`. This is equivalent to `cond(:owns)`, but as a matter of
  general style, bare words are preferred.
- `~` to negate any rule. For example `~owns`, or `~(intoxicated | banned)`.
- `&` or `all?` to combine rules such that all must succeed. For example:
  `old_enough_to_drive & has_driving_license` or `all?(old_enough_to_drive, has_driving_license)`.
- `|` or `any?` to combine rules such that one must succeed. For example:
  `intoxicated | banned` or `any?(intoxicated, banned)`.
- `can?` to refer to the result of evaluating an ability. For example,
  `can?(:sell_vehicle)`.
- `delegate(:delegate_name, :condition_name)` to refer to a specific
  condition on a named delegate. Use of this is rare, but can be used to
  handle overrides. For example if a vehicle policy defines a delegate as
  `delegate :registration`, then we could refer to that
  as `rule { delegate(:registration, :valid) }`.

Note: Be careful not to confuse `DeclarativePolicy::Base.condition` with
`DeclarativePolicy::RuleDSL#cond`.

- `condition` constructs a condition from a name and a block. For example:
  `condition(:adult) { @subject.age >= country.age_of_majority }`.
- `cond` constructs a rule which refers to a condition by name. For example:
  `rule { cond(:adult) }.enable :vote`. Use of `cond` is rare - it is nicer to
  use the bare word form: `rule { adult }.enable :vote`.

### Complex conditions

Conditions may be combined in the rule blocks:

```ruby
# A or B
rule { owns | has_access_to }.enable :drive_vehicle
# A and B
rule { has_driving_license & old_enough_to_drive }.enable :drive_vehicle
# Not A
rule { ~has_driving_license }.prevent :drive_vehicle
```

And conditions can be implied from abilities:

```ruby
rule { can?(:drive_vehicle) }.enable :drive_taxi
```

### Delegation

Policies may delegate to other policies. For example we could have a
`DrivingLicense` class, and a `DrivingLicensePolicy`, which might contain rules
like:

```ruby
class DrivingLicensePolicy < DeclarativePolicy::Base
  condition(:expired) { @subject.expires_at <= Time.current }
  
  rule { expired }.prevent :drive_vehicle
end
```

And a registration policy:

```ruby
class RegistrationPolicy < DeclarativePolicy::Base
  condition(:valid) { @subject.valid_for?(@user.current_location) }
  
  rule { ~valid }.prevent :drive_vehicle
end
```

Then in our `VehiclePolicy` we can delegate the license and registration
checking to these two policies:

```ruby
delegate { @user.driving_license }
delegate { @subject.registration }
```

This is a powerful mechanism for inferring rules based on relationships between
objects.
