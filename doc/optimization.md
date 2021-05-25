# Optimization

This library cares a lot about performance, and includes features that
aim to limit the impact of permission checks on an application. In particular,
effort is made to ensure that repeated checks of the same permission are
efficient, aiming to eliminate repeated computation and unnecessary I/O.

The key observation: permission checks generally involve some facts
about the real world, and this involves (relatively expensive) I/O to compute.
These facts are then combined in some way to generate a judgment. Not all facts
are necessary to know in order to determine a judgment. The main aims of the
library:

- Avoid unnecessary work.
- If we must do work, do the least work possible.

The library enables you to define both how to compute these facts
(conditions), and how to combine them (rules), but the library is entirely
responsible for the scheduling of when to compute each fact.

## Making truth

This library is essentially a build-system for truth - you can think of it as
similar to [`make`](https://www.gnu.org/software/make/), but:

- Instead of `targets` there are `abilities`.
- Instead of `files`, we produce `boolean` values.

We have no notion of freshness - uncached conditions are always re-computed, but
just like `make`, we try to do the least work possible in order to evaluate the
given ability.

For the interested, this corresponds to
[`memo`](https://hackage.haskell.org/package/build-1.0/docs/src/Build.System.html#memo) in
the taxonomy of build systems (although the scheduler here is somewhat smarter
about the relative order of dependencies).

## Optimization is reducing computation of expensive I/O

In the context of this library, optimization refers to ways we can:

- Expose the smallest possible units of I/O to the scheduler.
- Never run a computation twice.
- Indicate to the scheduler which computations should be run first.

For example, if a policy defines the following rule:

```ruby
rule { fact_a & fact_b }.enable :some_ability
```

The core of the matter: if we know in advance that `fact_a == false`, then we do not need to compute
`fact_b`. Conversely, if we know in advance that `fact_b == false`, then we do
not need to run `fact_a`. The same goes for `fact_a | fact_a`.

In this case:

- The smallest possible units of I/O are `fact_a` and `fact_b`, and the library
  is aware of them.
- The library uses the [cache](./caching.md) to avoid running a condition more
  than once.
- It does not matter which order we run these conditions in - the scheduler is
  free to re-order them if it thinks that `fact_b` is somehow more efficient to
  compute than `fact_a`.

## The scheduling logic

The problem each permission check seeks to solve is determining the truth value
of a proposition of the form:

```pseudo
any? enabling-conditions && not (any? preventing-conditions)
```

If `[a, b, c]` are enabling conditions, and `[x, y, z]` are preventing
conditions, then this could be expressed as:

```ruby
(a | b | c) & ~x & ~y & ~z
```

But the [scheduler](../lib/declarative_policy/runner.rb) represents this
as a flat list of rules - conditions and their outcomes:

```pseudo
[
  (a, :enable),
  (b, :enable),
  (c, :enable),
  (x, :prevent),
  (y, :prevent),
  (z, :prevent)
]
```

They aren't necessarily run in this order, however. Instead, we try to order
the list to minimize unnecessary work.

The
[logic](https://gitlab.com/gitlab-org/declarative-policy/blob/659ac0525773a76cf8712d47b3c2dadd03b758c9/lib/declarative_policy/runner.rb#L80-112)
to process this list is (in pseudo-code):

```pseudo
while any-enable-rule-remains?(rules)
  rule := pop-cheapest-remaining-rule(rules)
  fact := observe-io-and-update-cache rule.condition

  if fact and rule.prevents?
    return prevented
  else if fact and rule.enables?
    skip-all-other-enabling-rules!
    enabled? := true

if enabled?
  return enabled
else
  return prevented
```

The process for ordering rules is that each condition has a score, and we prefer
the rules with the lowest `score`. Cached values have a score of `0`. Composite
conditions (such as `a | b | c`) have a score that the sum of the scores of
their components.

The evaluation of one rule results in updating the cache, so other rules might
become cheaper, during policy evaluation. To take this into account, we re-score
the set of rules on each iteration of the main loop.

## Consequences for the policy-writer

While interesting in its own right, this has some practical consequences for the
policy writer:

### Flat is better than nested

The scheduler can do a better job of arranging work into the smallest possible
chunks if the definitions are as flat as possible, meaning this:

```ruby
rule { condition_a }.enable :some_ability
rule { condition_b }.prevent :some_ability
```

Is easier to optimise than:

```ruby
rule { condition_a & ~condition_b }.enable :some_ability
```

We do attempt to flatten and de-nest logical expressions, but it is not always
possible to raise all expressions to the top level. All things being
equal, we recommend using the declarative style.

#### An example of sub-optimal scheduling

The scheduler is only able to re-order conditions that can be flattened out to
the top level. For example, given the following definition:

```ruby
condition(:a, score: 1) { ... }
condition(:b, score: 2) { ... }
condition(:c, score: 3) { ... }

rule { a & c }.enable :some_ability
rule { b & c }.enable :some_ability
```

The conditions are evaluated in the following order:

- `a & c` (score = 4):
  - `a` (score = 1)
  - `c` (score = 3)
- `b & c` (score = 3):
  - `c` (score = 0 [cached])
  - `b` (score = 2)

If instead this were three top level rules:

```ruby
rule { a }.enable :some_ability
rule { b }.enable :some_ability
rule { ~c }.prevent :some_ability
```

Then this would be evaluated as:

- `a` (score = 1)
- `b` (score = 2)
- `c` (score = 3)

If `a` and `b` fail, then `3` is never evaluated, saving the most
expensive call.

The total evaluated costs for each arrangement are:

| Failing conditions | Nested cost     | Flat cost     |
|--------------------|-----------------|---------------|
| none               | 4 `(a, c)`      | 4 `(a, c)`    |
| all                | 3 `(a, b)`      | 3 `(a, b)`    |
| `a`                | 6 `(a, b, c)`   | 6 `(a, b, c)` |
| `b`                | 4 `(a, c)`      | 4 `(a, c)`    |
| `c`                | 4 `(a, c, c=0)` | 4 `(a, c)`    |
| `a` and `b`        | 4 `(a, c, c=0)` | 3 `(a, b)`    |
| `a` and `c`        | 6 `(a, b, c)`   | 6 `(a, b, c)` |
| `b` and `c`        | 4 `(a, c, c=0)` | 4 `(a, c)`    |

While the overall costs for all arrangements are very similar,
the flat representation is strictly superior, and does not even need to
rely on the cache for this behavior.

### Getting the scope right matters

By default, the outcome of each rule is cached against a key like
`(rule.condition.key, user.key, subject.key)`. (For more information, read
[caching](./caching.md).) This makes sense for some things like:

```ruby
condition(:owns_vehicle) { @user == @subject.owner }
```

In this case, the result depends on both the `@user` and the `@subject`. Not all
conditions are like that, though! The following condition only refers to the
subject:

```ruby
condition(:roadworthy) { @subject.warrant_of_fitness.current? }
```

If we cached this against `(user_a, car_a)` and then tested it
against `(user_b, car_a)` it would not match, and we would have to re-compute
the condition, even though the road-worthiness of a vehicle does not depend on
the driver. See [caching](./caching.md) for more discussion on scopes.

Because more general conditions are more sharable, all things being equal, it is
better to evaluate a condition that might be shared later, rather than one that
is less likely to be shared. For this reason, when we sort the rules,
we prefer ones with more general scopes to more specific ones.

### Getting the score right matters

Each condition has a `score`, which is an abstract weight. By default this is
determined by the scope.

However, if you know that a condition is very expensive to run, then it makes sense
to give it a higher score, meaning it's only evaluated if we really need
to. On the other hand, if a condition is very likely to be determinative, then
giving it a lower score would ensure we test it first.

For example, take two conditions, one which queries the local DB, and one
which makes an external API call. If they are otherwise equivalent, calling
the database one first is likely to be more efficient, as it might save us needing
to make the external API call. Conditions that are
[pure](https://en.wikipedia.org/wiki/Pure_function) can even be given a value of
`0`, as no I/O is required to compute them.

```ruby
condition(:local_db) { @subject.related_object.present? }
condition(:pure, score: 0) { @subject.some_attribute? }
condition(:external_api, score: API_SCORE) { ExtrnalService.get(@subject.id).ok? }

# these are run in the order: pure, local_db, external_api
rule { external_api & pure & local_db }.enable :some_ability
```

The other consideration is the likelihood that a condition is determinative. For
example, if `condition_a` is true 80% of the time, and `condition_b` is true
20% of the time, then we should prefer to run `condition_a` if these conditions
enable an ability (because 80% of the time we don't need to run `condition_b`).
But if they prevent an ability, then we would prefer to run `condition_b` first,
because again, 80% of the time we can skip `condition_a`. This consideration is
more subtle. It requires knowing both the distribution of the condition, and
the consequence of its outcome, but this can be used to further optimize the
order of evaluation by marking some conditions as more likely to affect the
outcome.

All things being equal, we prefer to run prevent rules, because they have this
property - they are more likely to save extra work.
