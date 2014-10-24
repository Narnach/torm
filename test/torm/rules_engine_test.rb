require 'minitest_helper'

describe Torm::RulesEngine do
  let(:engine) { Torm::RulesEngine.new }

  describe '#add_rule and #decide' do
    describe 'basic decision making' do
      before(:each) do
        engine.add_rule 'show unsubscribe link', false, :default
        engine.add_rule 'show unsubscribe link', true, :coc, country: 'FR'
      end

      it 'should pick the default without any conditions' do
        # This means it should *not* apply rules which only apply to conditions we don't have
        engine.decide('show unsubscribe link').must_equal false
      end

      it 'should pick a specific rule over the default' do
        engine.decide('show unsubscribe link', country: 'FR').must_equal true
      end

      it 'should ignore conditions which do not match' do
        engine.decide('show unsubscribe link', country: 'NL', happy: true, season: :summer).must_equal false

        engine.add_rule 'show unsubscribe link', true, :default, season: :summer
        engine.decide('show unsubscribe link', country: 'NL', happy: true, season: :summer).must_equal true
      end
    end

    describe 'range behavior' do
      it 'should support maximum' do
        engine.add_rule 'FSK level', { maximum: 18 }, :default
        engine.add_rule 'FSK level', { maximum: 16 }, :coc, referrer: 'google'
        engine.add_rule 'FSK level', { maximum: 12 }, :coc, referrer: 'disney'
        engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'FR'
        engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'DE'
        engine.add_rule 'FSK level', { maximum: 12 }, :law, country: 'TR'

        # Default
        engine.decide('FSK level').must_equal({ maximum: 18 })
        # Default
        engine.decide('FSK level', country: 'NL').must_equal({ maximum: 18 })
        # CoC for DE
        engine.decide('FSK level', country: 'DE').must_equal({ maximum: 16 })
        # ref=google
        engine.decide('FSK level', country: 'NL', referrer: 'google').must_equal({ maximum: 16 })

        # should start with 12+ for TR, and not modify it to 16+ for ref=google
        engine.decide('FSK level', country: 'TR', referrer: 'google').must_equal({ maximum: 12 })

        # should start with 16+ for FR, but tighten it to 12+ for ref=disney
        engine.decide('FSK level', country: 'FR', referrer: 'disney').must_equal({ maximum: 12 })
      end

      it 'should support minimum' do
        engine.add_rule 'FSK level', { minimum: 1 }, :default
        engine.add_rule 'FSK level', { minimum: 12 }, :default, sexy: true
        engine.add_rule 'FSK level', { minimum: 16 }, :default, softcore: true
        engine.add_rule 'FSK level', { minimum: 18 }, :default, hardcore: true


        # Query individual FSK thresholds
        engine.decide('FSK level').must_equal({ minimum: 1 })
        engine.decide('FSK level', sexy: true).must_equal({ minimum: 12 })
        engine.decide('FSK level', softcore: true).must_equal({ minimum: 16 })
        engine.decide('FSK level', hardcore: true).must_equal({ minimum: 18 })

        # Combine multiple FSK threshold
        #engine.verbose = true
        engine.decide('FSK level', hardcore: true, sexy: true).must_equal({ minimum: 18 })
        engine.decide('FSK level', softcore: true, sexy: true).must_equal({ minimum: 16 })
      end

      it 'should combine minimum and maximum' do
        engine.add_rule 'FSK level', { minimum: 1, maximum: 18 }, :default
        engine.add_rule 'FSK level', { maximum: 16 }, :coc, referrer: 'google'
        engine.add_rule 'FSK level', { maximum: 12 }, :coc, referrer: 'disney'
        engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'FR'
        engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'DE'
        engine.add_rule 'FSK level', { maximum: 12 }, :law, country: 'TR'

        engine.add_rule 'FSK level', { minimum: 12 }, :default, sexy: true
        engine.add_rule 'FSK level', { minimum: 16 }, :default, softcore: true
        engine.add_rule 'FSK level', { minimum: 18 }, :default, hardcore: true

        engine.decide('FSK level', country: 'NL').must_equal({ minimum: 1, maximum: 18 })
        engine.decide('FSK level', country: 'FR').must_equal({ minimum: 1, maximum: 16 })
        engine.decide('FSK level', country: 'FR', sexy: true).must_equal({ minimum: 12, maximum: 16 })

        # Return nil because of conflicting requirements: softcore is 16+, TR is 12-
        engine.decide('FSK level', country: 'TR', softcore: true).must_equal nil
      end

      it 'should allow range syntax' do
        engine.add_rule 'FSK level', 1..18, :default
        engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'FR'
        engine.add_rule 'FSK level', { minimum: 12 }, :default, sexy: true

        engine.decide('FSK level', country: 'NL').must_equal({ minimum: 1, maximum: 18 })
        engine.decide('FSK level', country: 'FR', sexy: true).must_equal({ minimum: 12, maximum: 16 })
      end
    end

    describe '#add_rules block syntax' do
      it 'should yield an object that responds to :variation to add rules' do
        engine.add_rules 'Happy', true, :default do |rule|
          # Nobody likes rain...
          rule.variation false, :default, rain: true
          # ...except for the Brits :-)
          rule.variation true, :law, rain: true, country: 'GB'
        end

        assert engine.decide('Happy')
        refute engine.decide('Happy', rain: true)
        assert engine.decide('Happy', rain: true, country: 'GB')
      end

      it 'should yield an object that responds to :conditions to yield a block with those conditions applied' do
        engine.add_rules 'Happy', true, :default do |rule|
          # Setup general conditions for the entire block
          rule.conditions rain: true do |rule|
            # Nobody likes rain...
            rule.variation false, :default
            # ...except for the Brits :-)
            rule.variation true, :law, country: 'GB'

            rule.conditions umbrella: true do |rule|
              # ...or people with an umbrella
              rule.variation true, :law
              # Red umbrellas still make people grumpy, though.
              rule.variation false, :law, umbrella_color: :red
            end
          end
        end

        assert engine.decide('Happy')
        refute engine.decide('Happy', rain: true)
        assert engine.decide('Happy', rain: true, country: 'GB')
        assert engine.decide('Happy', rain: true, umbrella: true)
        refute engine.decide('Happy', rain: true, umbrella: true, umbrella_color: :red)
      end
    end
  end

  describe '#to_json' do
    it 'should export all rules as a Hash' do
      engine.add_rule 'FSK level', 1..18, :default
      engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'FR'
      engine.add_rule 'FSK level', { minimum: 12 }, :default, sexy: true

      rule_hash = {
        policies: [:law, :coc, :experiment, :default],
        rules:    {
          'FSK level' => [
            { policy: :coc, value: { maximum: 16 }, conditions: { country: 'FR' } },
            { policy: :default, value: { minimum: 12 }, conditions: { sexy: true } },
            { policy: :default, value: { minimum: 1, maximum: 18 }, conditions: {} },
          ]
        }
      }
      engine.as_hash.must_equal rule_hash

      engine.to_json.must_equal MultiJson.dump(engine.as_hash)
    end
  end

  describe '.from_json' do
    it 'should return a working rules engine' do
      engine.add_rule 'FSK level', 1..18, :default
      engine.add_rule 'FSK level', { maximum: 16 }, :coc, country: 'FR'
      engine.add_rule 'FSK level', { minimum: 12 }, :default, sexy: true

      engine.decide('FSK level', country: 'NL').must_equal({ minimum: 1, maximum: 18 })
      engine.decide('FSK level', country: 'FR', sexy: true).must_equal({ minimum: 12, maximum: 16 })

      engine2 = Torm::RulesEngine.from_json(engine.to_json)
      engine2.as_hash.must_equal engine.as_hash

      engine2.decide('FSK level', country: 'NL').must_equal({ minimum: 1, maximum: 18 })
      engine2.decide('FSK level', country: 'FR', sexy: true).must_equal({ minimum: 12, maximum: 16 })
    end
  end
end
