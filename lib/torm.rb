# External dependencies
require 'multi_json'

# No internal dependencies
require 'torm/version'
require 'torm/tools'

# This is where the magic happens
require 'torm/rules_engine'

module Torm
  class << self
    include Tools

    attr_accessor :instance, :default_rules_file

    def instance
      @instance ||= RulesEngine.load || RulesEngine.new
    end

    def default_rules_file
      @default_rules_file ||= File.expand_path('tmp/rules.json')
    end

    # Load an engine with the current rules, yield it (to add rules) and then save it if rules were added.
    def set_defaults(engine: instance)
      yield engine
      engine.save if engine.dirty?
    end
  end
end
