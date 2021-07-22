# Caching

This library deals with making observations about the state of
a system (usually performing I/O, such as making a database query),
and combining these facts into logical propositions.

In order to make this performant, the library transparently caches repeated
observations of conditions. Understanding how caching works is useful for
designing good policies, using them effectively.

## What is cached?

If a policy is instantiated with a cache, then the following things will be
stored in it:

- Policy instances (there will only ever be one policy per `user/subject` pair
  for the lifetime of the cache).
- Condition results

The correctness of these cached values depends on the correctness of the
cache-keys. We assume the objects in your domain have a `#id` method that
fully captures the notion of object identity. See [Cache keys](#cache-keys) for
details. All cache keys begin with `"/dp/"`.

Policies themselves cache the results of the abilities they compute.

Policies distinguish between facts based on the type of the fact:

- Boolean facts: implemented with `condition`.
- Abilities: implemented with `rule` blocks.
- Non-boolean facts: implemented by policy instance methods.

For example, consider a policy for countries:

```ruby
class CountryPolicy < DeclarativePolicy::Base
  condition(:citizen) { @user.citizen_of?(country.country_code) }
  condition(:eu_citizen, scope: :user) { @user.citizen_of?(*Unions::EU) }
  condition(:eu_member, scope: :subject) { Unions::EU.include?(country.country_code) }

  condition(:has_visa_waiver)    { country.visa_waivers.any? { |c| @user.citizen_of?(c) } }
  condition(:permanent_resident) { visa_category == :permanent }
  condition(:has_work_visa)      { visa_category == :work }
  condition(:has_current_visa)   { has_visa_waiver? || current_visa.present? }
  condition(:has_business_visa)  { has_visa_waiver? || has_work_visa? || visa_category == :business }

  condition(:full_rights, score: 20) { citizen? || permanent_resident? }
  condition(:banned) { country.banned_list.include?(@user) }

  rule { eu_member & eu_citizen }.enable :freedom_of_movement
  rule { full_rights | can?(:freedom_of_movement) }.enable :settle
  rule { can?(:settle) | has_current_visa }.enable :enter_country
  rule { can?(:settle) | has_business_visa }.enable :attend_meetings
  rule { can?(:settle) | has_work_visa }.enable :work
  rule { citizen }.enable :vote
  rule { ~citizen & ~permanent_resident }.enable :apply_for_visa
  rule { banned }.prevent :enter_country, :apply_for_visa

  def current_visa
    return @current_visa if defined?(@current_visa)

    @current_visa = country.active_visas.find_by(applicant: @user)
  end

  def visa_category
    current_visa&.category
  end

  def country
    @subject
  end
end
```

This is a reasonably realistic policy - there are a few pieces of state (the
country, the list of visa waiver agreements, the list of citizenships the user
holds, the kind of visa the user has, if they have one, the current list of
banned users), and these are combined to determine a range of abilities (whether
one can visit or live in or vote in a certain country). Importantly, these
pieces of information are re-used between abilities - the citizenship status is
relevant to all abilities, whereas the banned list is only considered on entry
and when applying for a new visa).

If we imagine that some of these operations are reasonably expensive (fetching
the current visa status, or checking the banned list, for example), then it
follows that we really care about avoiding re-computation of these facts. In the
policy above we can see a few strategies that are taken to avoid this:

- Conditions are re-used liberally.
- Non-boolean facts are cached at the policy level.

## Re-using conditions

Rules can and should re-use conditions as much as possible. Condition
observations are cached automatically, so referring to the same condition in
multiple rules is encouraged. Conditions can also refer to other conditions by
using the predicate methods that are created for them (see `full_rights`, which
refers to the `:citizen` condition as `citizen?`).

Note that referring to conditions inside other conditions can be DRY, but it
limits the ability of the library to optimize the steps (see
[optimization](./optimization.md)). For example in the `:has_current_visa`
condition, the sub-conditions will always be tested in the order
`has_visa_waiver` then `current_visa.present?`. It is recommended not to rely
heavily on this kind of abstraction.

## Re-using rules

Entire rule-sets can be re-used with `can?`. This is a form of logical
implication where a previous conclusion can be used in a further rule. Examples
of this here are `can?(:settle)` and `can?(:freedom_of_movement)`. This can
prevent having to repeat long groups of conditions in rule definitions. This
abstraction is transparent to the optimizer.

## Non-boolean values must be managed manually

The condition `has_current_visa` and the more specific
`has_{work,business}_visa` all refer to the same piece of state - the
`#current_visa`. Since this is not a boolean (but is here a database record with
a `#category` attribute), this cannot be a condition, but must be managed by the
policy itself.

The best approach here is to use normal Ruby methods and instance variables for
such values. The policy instances themselves are cached, so that any two
invocations of `DeclarativePolicy.policy_for(user, object)` with identical
`user` and `object` arguments will always return the same policy object. This
means instance variables stored on the policy will be available for the lifetime
of the cache.

Methods can be used for the usual reasons of clarity (such as referring to the
`@subject` as `country`) and brevity (such as `visa_category`).

## Cache lifetime

The cache is provided by the user of the library, passing it to the
`.policy_for` method. For example:

```ruby
DeclarativePolicy.policy_for(user, country, cache: some_cache_value)
```

The object only needs to implement the following methods:

- `cache[key: String] -> Boolean?`: Fetch the cached value
- `cache.key?(key: String) -> Boolean`: Test if the key is cached
- `cache[key: String] = Boolean`: Cache a value

Obviously, a `HashMap` will work just fine, but so will a wrapper around a
[`Concurrent::Map`](https://ruby-concurrency.github.io/concurrent-ruby/1.1.4/Concurrent/Map.html),
or even a map that delegates to Redis with a TTL for each key, so long as the
object supports these methods. Keys are never deleted by the library, and values
are only computed if the key is not cached, so it is up to the application code
to determine the life-time of each key.

Clearly, cache-invalidation is a hard problem. At GitLab we share a single cache
object for each request - so any single request can freely request a permission
check multiple times (or even compute related abilities, such as
`:enter_country` and `:settle`) and know that no work is duplicated. This
allows developers to reason declaratively, and add permission checks where
needed, without worrying about performance.

## Cache sharing: scopes

Not all conditions are equally specific. The condition `citizen` refers to
both the user and the country, and so can only be used when checking both the
user and the country. We say that this is the `normal` scope.

This is not always true however. Sometimes a condition refers only to the user.
For example, above we have two conditions: `eu_citizen` and `eu_member`:

```ruby
  condition(:eu_citizen, scope: :user) { @user.citizen_of?(*Unions::EU) }
  condition(:eu_member, scope: :subject) { Unions::EU.include?(country.country_code) }
```

`eu_citizen` refers only to the user, and `eu_member` refers only to the
country.

If we have a user that wants to enter multiple countries on a grand European
tour, we could check this with:

```ruby
itinerary.countries.all? { |c| DeclarativePolicy.policy_for(user, c).allowed?(:enter_country) }
```

If `eu_citizen` were declared with the `normal` scope, then this would have a lot of cache
misses. By using the `:user` scope on `eu_citizen`, we only check EU citizenship
once.

Similarly for `eu_member`, if a team of football players want to visit a
country, then we could check this with:

```ruby
team.players.all? { |user| DeclarativePolicy.policy_for(user, country).allowed?(:enter_country) }
```

Again, by declaring `eu_member` as having the `:subject` scope, this ensures we
only check EU membership once, not once for each football player.

The last scope is `:global`, used when the condition is universally true:

```ruby
  condition(:earth_destroyed_by_meteor, scope: global) { !Planet::Earth.exists? }

  rule { earth_destroyed_by_meteor }.prevent_all
```

In this case, it doesn't matter who the user is or even where they are going:
the condition will be computed once (per cache lifetime) for all combinations.

Because of the implications for sharing, the scope determines the
[`#score`](https://gitlab.com/gitlab-org/declarative-policy/blob/2ab9dbdf44fb37beb8d0f7c131742d47ae9ef5d0/lib/declarative_policy/condition.rb#L58-77) of
the condition (if not provided explicitly). The intention is to prefer values we
are more likely (all other things being equal) to re-use:

- Conditions we have already cached get a score of `0`.
- Conditions that are in the `:global` scope get a score of `2`.
- Conditions that are in the `:user` or `:subject` scopes get a score of `8`.
- Conditions that are in the `:normal` scope get a score of `16`.

Bear helper-methods in mind when defining scopes. While the instance level cache
for non-boolean values would not be shared, as long as the derived condition is
shared (for example by being in the `:user` scope, rather than the `:normal`
scope), helper-methods will also benefit from improved cache hits.

### Preferred scope

In the example situations above (a single user visiting many countries, or a
football team visiting one country), we know which is more likely to be useful,
the `:subject` or the `:user` scope. We can inform the optimizer of this
by setting `DeclarativePolicy.preferred_scope`.

To do this, check the abilities within a block bounded
by [`DeclarativePolicy.with_preferred_scope`](https://gitlab.com/gitlab-org/declarative-policy/blob/481c322a74f76c325d3ccab7f2f3cc2773e8168b/lib/declarative_policy/preferred_scope.rb#L7-13).
For example:

```ruby
cache = {}

# preferring to run user-scoped conditions
DeclarativePolicy.with_preferred_scope(:user) do
  itinerary.countries.all? do |c|
    DeclarativePolicy.policy_for(user, c, cache: cache).allowed?(:enter_country)
  end
end

# preferring to run subject-scoped conditions
DeclarativePolicy.with_preferred_scope(:subject) do
  team.players.all? do |player|
    DeclarativePolicy.policy_for(player, c, cache: cache).allowed?(:enter_country)
  end
end

```

When we set `preferred_scope`, this reduces the default score for conditions in
that scope, so that they are more likely to be executed first. Instead of `8`,
they are given a default score of `4`.

## Cache keys

In order for an object to be cached, it should be able to identify itself
with a suitable cache key. A good cache key will identify an object, without
containing irrelevant information - a database `#id` is perfect, and this
library defaults to calling an `#id` method on objects, falling back to
`object_id`.

Relying on `object_id` is not recommended since otherwise equivalent objects
have different `object_id` values, and using `object_id` will not get optimal caching. All
policy subjects should implement `#id` for this reason. `ActiveRecord` models
with an `id` primary ID attribute do not need any extra configuration.

Please see: [`DeclarativePolicy::Cache`](https://gitlab.com/gitlab-org/declarative-policy/blob/master/lib/declarative_policy/cache.rb).

## Cache invalidation

Generally, cache invalidation is best avoided. It is very hard to get right, and
relying on it opens you up to subtle but pernicious bugs that are hard to
reproduce and debug.

The best strategy is to run all permission checks upfront, before mutating any
state that might change a permission computation. For instance, if you want to
make a user an administrator, then check for permission **before** assigning
administrator privileges.

However, it isn't always possible to avoid needing to mark certain parts of the
cached state as dirty (in need of re-computation). If this is needed, then you
can call the `DeclarativePolicy.invalidate(cache, keys)` method. This takes an
enumerable of dirty keys, and:

- removes the cached condition results from the cache
- marks the abilities that depend on those conditions as dirty, and in need of
  re-computation.

The responsibility for determining which cache-keys are dirty falls on the
client. You could, for example, do this by observing which keys are added to the
cache (knowing that condition keys all start with `"/dp/condition/"`), or by
scanning the cache for keys that match a heuristic.

This method is the only place where the `#delete` method is called on the cache.
If you do not call `.invalidate`, there is no need for the cache to implement
`#delete`.
