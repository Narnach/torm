module Torm
 class RulesEngine
    # Policies (priorities) in order of important -> least important.
    DEFAULT_POLICIES = [:law, :coc, :experiment, :default].freeze

    attr_reader :rules
    attr_accessor :verbose, :policies, :conditions_whitelist
    attr_accessor :dirty

    def initialize(rules: {}, conditions_whitelist: {}, dirty: false, policies: DEFAULT_POLICIES.dup, verbose: false)
      @rules                = rules
      @conditions_whitelist = conditions_whitelist
      @dirty                = dirty
      @policies             = policies
      @verbose              = verbose
    end

    # Have any rules been added since the last save or load?
    def dirty?
      @dirty
    end

    # Add a new rule.
    # Will mark the engine as dirty when a rules was added.
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

    def decide(name, environment={})
      raise "Unknown rule: #{name.inspect}" unless rules.has_key?(name)
      environment          = Torm.symbolize_keys(environment)
      decision_environment = Torm.slice(environment, *conditions_whitelist_for(name))
      answer               = make_decision(name, decision_environment)
      #Rails.logger.debug "DECISION: #{answer.inspect} (#{name.inspect} -> #{environment.inspect})"
      answer
    end

    def as_hash
      {
        policies: policies,
        rules:    rules
      }
    end

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
      engine = new(data)
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

    # Where we store the rules file.
    def self.rules_file
      Rails.root.join('tmp', 'rules.json').to_s
    end

    # Load rules from a file and create a new engine for it.
    # Note: this does *not* replace the Torm::RulesEngine.instance, you have to do this yourself if required.
    #
    # @return [Torm::RulesEngine] A new engine with the loaded rules
    def self.load(rules_file: Torm.default_rules_file)
      if File.exist?(rules_file)
        json = File.read(rules_file)
        self.from_json(json)
      else
        nil
      end
    end

    # Save the current rules to a file.
    def save(rules_file: self.class.rules_file)
      Torm.atomic_save(rules_file, to_json + "\n")
      @dirty = false
      nil
    end

    private

    # TODO: Refactor once useful
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

    def puts(message)
      Kernel.puts(message) if verbose
    end

    def pp(object)
      Kernel.pp(object) if verbose
    end
  end
end
