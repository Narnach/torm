module Torm
  class RulesEngine
    # Policies (priorities) in order of important -> least important.
    DEFAULT_POLICIES = [:law, :coc, :experiment, :default].freeze

    attr_reader :rules, :conditions_whitelist
    attr_accessor :policies
    attr_accessor :dirty, :rules_file

    def initialize(rules: {}, dirty: false, policies: DEFAULT_POLICIES.dup, rules_file: Torm.default_rules_file)
      @rules                = rules
      @dirty                = dirty
      @policies             = policies
      @rules_file           = rules_file
      @conditions_whitelist = {}
    end

    # Have any rules been added since the last save or load?
    # @return [true, false]
    def dirty?
      @dirty
    end

    # Add a new rule.
    # Will mark the engine as dirty when a rules was added.
    #
    # @param [String] name
    # @param [true, false, String, Numeric, Range, Hash] value Either a simple type, or a Range, or a Hash with a :minimum or :maximum key to represent a Range extreme.
    # @param [Symbol] policy The source of the rule and thus how heavy it weighs.
    # @param [Hash] conditions Conditions that must be met before a rule evaluates to return this value.
    #
    # @return [Torm::RulesEngine] (self) Returns the engine that rules were added to.
    def add_rule(name, value, policy, conditions={})
      raise "Illegal policy: #{policy.inspect}, must be one of: #{policies.inspect}" unless policies.include?(policy)
      rules_array = rules_for(name)
      value       = { minimum: value.min, maximum: value.max } if Range === value
      new_rule    = { value: value.freeze, policy: policy, conditions: conditions.freeze }.freeze
      unless rules_array.include?(new_rule)
        rules_array << new_rule
        # Sort rules so that the highest policy level is sorted first and then the most complex rule before the more general ones
        rules_array.sort_by! { |rule| [policies.index(rule[:policy]), -rule[:conditions].size] }
        conditions_whitelist_for(name).merge conditions.keys
        @dirty = true
      end
      self
    end

    # Simple helper class to add the block DSL to add_rules
    class RuleVariationHelper
      def initialize(engine, name, **conditions)
        @engine = engine
        @name = name
        @conditions = conditions
      end

      def variation(value, policy, **conditions)
        @engine.add_rule(@name, value, policy, @conditions.merge(conditions))
        nil
      end

      # @yield [Torm::RulesEngine::RulesVariationHelper]
      def conditions(**conditions)
        engine = self.class.new(@engine, @name, **@conditions.merge(conditions))
        yield engine
        nil
      end
    end

    # Add multiple rules via the block syntax:
    #
    # @example
    #
    #   engine = Torm::RulesEngine.new
    #   engine.add_rules 'Happy', true, :default do |rule|
    #     rule.variant false, :default, rain: true
    #   end
    #
    # @param [String] name
    # @param [true, false, String, Numeric, Range, Hash] value Either a simple type, or a Range, or a Hash with a :minimum or :maximum key to represent a Range extreme.
    # @param [Symbol] policy The source of the rule and thus how heavy it weighs.
    #
    # @yield [Torm::RulesEngine::RuleVariationHelper]
    #
    # @return [Torm::RulesEngine] Returns self
    def add_rules(name, value, policy)
      # Add the default rule
      add_rule(name, value, policy)

      rule_variation = RuleVariationHelper.new(self, name)
      yield rule_variation if block_given?

      self
    end

    # Evaluate a rule and return its result. Depending on the rule, different values are returned.
    #
    # @raise [RuntimeError] Raise when the rule is not defined.
    def decide(name, environment={})
      raise "Unknown rule: #{name.inspect}" unless rules.has_key?(name)
      environment          = Torm.symbolize_keys(environment)
      decision_environment = Torm.slice(environment, *conditions_whitelist_for(name))
      answer               = make_decision(name, decision_environment)
      answer
    end

    # Return a hash with all rules and policies, useful for serialisation.
    #
    # @return [Hash]
    def as_hash
      {
        policies: policies,
        rules:    rules
      }
    end

    # Serialise the data from +as_hash+.
    #
    # @return [String]
    def to_json
      MultiJson.dump(as_hash)
    end

    # Load an engine from JSON. This means we can export rules engines across systems: store rules in 1 place, run them 'everywhere' at native speed.
    # Due to the high number of symbols we use, we have to convert the JSON string data for each rule on import.
    # Good thing: we should only have to do this once on boot.
    def self.from_json(json)
      dump   = MultiJson.load(json)
      data   = {
        policies: dump['policies'].map(&:to_sym),
      }
      engine = new(**data)
      dump['rules'].each do |name, rules|
        rules.each do |rule|
          value      = rule['value']
          value      = Torm.symbolize_keys(value) if Hash === value
          policy     = rule['policy'].to_sym
          conditions = Torm.symbolize_keys(rule['conditions'])
          engine.add_rule(name, value, policy, conditions)
        end
      end
      engine.dirty = false
      engine
    end

    # Load rules from a file and create a new engine for it.
    # Note: this does *not* replace the Torm::RulesEngine.instance, you have to do this yourself if required.
    #
    # @return [Torm::RulesEngine] A new engine with the loaded rules
    def self.load(rules_file: Torm.default_rules_file)
      if File.exist?(rules_file)
        json              = File.read(rules_file)
        engine            = self.from_json(json)
        engine.rules_file = rules_file
        engine
      else
        nil
      end
    end

    # Save the current rules to the file.
    def save
      Torm.atomic_save(rules_file, to_json + "\n")
      @dirty = false
      nil
    end

    private

    def make_decision(name, environment={})
      # Fetch all rules for this decision. Duplicate to allow us to manipulate the Array with #reject!
      relevant_rules = rules_for(name).dup

      # Filter through all rules. Eliminate the rules not matching our environment.
      relevant_rules.reject! do |rule|
        reject_rule = false
        rule[:conditions].each do |condition, value|
          if environment.has_key?(condition)
            if environment[condition] == value
              # This rule condition applies to our environment, so evaluate the next condition
              next
            else
              # The rule has a condition which is a mismatch with our environment, so it does not apply
              reject_rule = true
              break
            end
          else
            # The rule is more specific than our environment, so it does not apply
            reject_rule = true
            break
          end
        end
        reject_rule
      end

      # Check the remaining rules in order of priority
      result = nil
      relevant_rules.each do |rule|
        rule_value = rule[:value]
        case rule_value
        when Hash
          result ||= rule_value.dup
          # Lower-priority rules can decrease a maximum value, but not increase it
          if rule_value[:maximum]
            if result[:maximum]
              result[:maximum] = rule_value[:maximum] if rule_value[:maximum] < result[:maximum]
            else
              result[:maximum] = rule_value[:maximum]
            end
          end

          # Lower-priority rules can increase a minimum value, but not decrease it
          if rule_value[:minimum]
            if result[:minimum]
              result[:minimum] = rule_value[:minimum] if rule_value[:minimum] > result[:minimum]
            else
              result[:minimum] = rule_value[:minimum]
            end
          end

          # Minimum above maximum is invalid, so reject the result and return nil
          return nil if result[:minimum] && result[:maximum] && result[:minimum] > result[:maximum]
        else
          return rule_value
        end
      end
      result
    end

    def conditions_whitelist_for(name)
      conditions_whitelist[name] ||= Set.new
    end

    def rules_for(name)
      rules[name] ||= []
    end
  end
end
