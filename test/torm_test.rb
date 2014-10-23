require 'minitest_helper'

describe Torm do
  describe '.instance' do
    it 'should load an Engine with default rules when there is a default rules file'
    it 'should instantiate a new Engine when there are no default rules'
    it 'should return the same instance when one has already been accessed'
  end

  describe '.set_defaults' do
    it 'should yield the engine'
    it 'should save the engine when dirty after running the block'
  end
end
