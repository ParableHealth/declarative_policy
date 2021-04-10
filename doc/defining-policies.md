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

## Defining rules in the DSL

The DSL has two primary parts: defining **conditions** and **rules**.

For example, imagine we have a data model containing vehicles and users, and we
want to know if a user can drive a vehicle. We need a `VehiclePolicy`:

### Conditions

Conditions are facts about the state of the system

```ruby
condition(:owns) { @subject.owner == @user }
condition(:has_access_to) { @subject.owner.trusts?(@user) }
condition(:old_enough_to_drive) { @user.age >= laws.minimum_age }
condition(:has_driving_license) { @user.driving_license&.valid? }
condition(:intoxicated, score: 5) { @user.blood_alcohol < laws.max_blood_alcohol }
condition(:has_access_to, score: 3) { @subject.owner.trusts?(@user) }
```

These can be defined in any order, but we consider it best practice to define
conditions at the top of the file.

### Rules

Rules are conclusions we can draw based on the facts:

```ruby
rule { owns }.enable :drive_vehicle
rule { has_access_to }.enable :drive_vehicle
rule { ~old_enough_to_drive }.prevent :drive_vehicle
rule { intoxicated }.prevent :drive_vehicle
rule { ~has_driving_license }.prevent :drive_vehicle
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
