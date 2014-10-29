# Torm

![CodeClimate Score]( https://codeclimate.com/repos/5450f148e30ba0588901cf3e/badges/29e37e62425a2442acb2/gpa.svg )
![Code Coverage]( https://codeclimate.com/repos/5450f148e30ba0588901cf3e/badges/29e37e62425a2442acb2/coverage.svg )
[![Codeship Status for Narnach/torm](https://www.codeship.io/projects/e8e50340-41a1-0132-b130-460890c716b2/status)](https://www.codeship.io/projects/44218)

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

## Example in a (Rails) app context

Load the rules engine, define defaults so new rules get saved.

```ruby
# Set a custom rules file before accessing the default rules engine.
Torm.default_rules_file = Rails.root.join('tmp/my_rules.json').to_s

# Torm.set_defaults will load an engine if a rules file exists, otherwise you get an empty engine.
# Add rules, then after the block it will automatically save the rules file when new rules were changed.
Torm.set_defaults do |engine|
  # Setup custom priorities. Higher priority rules take precedence over lower ones.
  engine.priorities = [:high, :medium, :low, :default]

  # Add a new rule named 'Happy', with a value of true as 'default' policy
  engine.add_rules 'Happy', true, :default do |rule|
    # Setup general conditions for the rest of the block
    rule.conditions rain: true do |rule|
      # By default, nobody likes rain...
      rule.variation false, :default
      # ...except for the Brits. They love rain :-)
      rule.variation true, :high, country: 'GB'

      rule.conditions umbrella: true do |rule|
        # People with an umbrella don't mind rain.
        rule.variation true, :high
        # Red umbrellas still make people grumpy, though.
        rule.variation false, :medium, umbrella_color: :red
      end
    end
  end
end

# Torm.instance holds the default engine used by Torm.set_defaults, so we can use it for making decisions.
Torm.instance.decide('Happy', country: 'NL')                # => true
Torm.instance.decide('Happy', country: 'NL', rain: true)    # => false
Torm.instance.decide('Happy', country: 'GB', rain: true)    # => true


# If you need more rules engines, instantiate a non-global engine when you need one.
engine = Torm::RulesEngine.new
engine.add_rule 'Happy', true, :default
engine.decide('Happy', country: 'NL') # => true
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
