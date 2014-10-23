# Torm

Torm is a rules engine build in Ruby. It is named after [Torm](http://forgottenrealms.wikia.com/wiki/Torm), the Forgotten Realms god of Law.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'torm'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install torm

## Usage

```ruby
# Setup a new engine
engine = Torm::RulesEngine.new

# Define a bunch of rules: name, value/range, priority, conditions
# Each rule should at least have a default value without any conditions.
# Default priorities: :law > :coc > :experiment > :default
engine.add_rule 'FSK level', 1..18, :default
engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'FR'
engine.add_rule 'FSK level', { minimum: 12 }, :default, sexy: true

# Let the engine decide which rules apply and how they intersect
engine.decide('FSK level', country: 'NL')              # => {minimum: 1, maximum: 18}
engine.decide('FSK level', country: 'FR', sexy: true)  # => {minimum: 12, maximum: 16}
```

## How rules are evaluated

* Policy origins dictate priority.
  * The lowest priority are the defaults. This is our company policy.
  * On top of defaults we can run experiments.
  * The Code of Conduct (usually specific to a country + payment method) overrules our policies and experiments
  * Law (usually specific to a country) overrules everything
* Rules have a set of zero or more conditions
  * Each condition must be met in order for a rule to be relevant
  * On equal policy level, more specific rules (more conditions) overrule less specific ones. Rationale: "We usually don't do this, except when it's summer."
* Decisions take a rule and a bunch of environment conditions
  * We gather all rules, then filter irrelevant rules based on environment conditions
  * Because rules are stored in order of priority, the first rule remaining is the one that applies the best.

## Versioning

Torm tries to follow Semantic Versioning 2.0.0, this means that given a version number MAJOR.MINOR.PATCH, it will increment the:

* MAJOR version when you make incompatible API changes,
* MINOR version when you add functionality in a backwards-compatible manner, and
* PATCH version when you make backwards-compatible bug fixes.

As long as the MAJOR version is 0, all bets are off as the library has not been declared stable yet.
In this case, treat MINOR version changes as a sign to check the changelog for breaking chagnes.

## Contributing

1. Fork it ( https://github.com/narnach/torm/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
