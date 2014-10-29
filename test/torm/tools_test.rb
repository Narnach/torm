require 'minitest_helper'

# This module is included in Torm, so we use that to test its behavior.
describe Torm::Tools do
  describe '#atomic_save' do
    tmp_dir  = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'tmp'))
    tmp_file = "#{tmp_dir}/atomic.test"
    before do
      Dir.mkdir(tmp_dir) unless File.exist?(tmp_dir)
    end

    after do
      File.delete(tmp_file) if File.exist?(tmp_file)
    end

    it 'should save data to a file' do
      Torm.atomic_save(tmp_file, 'test')
      assert File.exist?(tmp_file)
      File.read(tmp_file).must_equal 'test'
    end
  end

  describe '#symbolize_keys' do
    it 'should convert string keys to symbols' do
      Torm.symbolize_keys({ 'a' => 'b', :c => :d }).must_equal({ a: 'b', c: :d })
    end
  end

  describe '#slice' do
    it 'should return a hash with only the white listed keys' do
      hash = {
        foo: 1,
        baz: 3
      }
      Torm.slice(hash, :foo, :bar).must_equal({ foo: 1 })

      # Ensure we did not modify the original Hash
      hash[:baz].must_equal 3
    end
  end
end
