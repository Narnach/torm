module Torm::Tools
  # Save data to a temporary file, then rename it to the final file.
  def atomic_save(target_file, data)
    tmp_file = target_file + ".#{Process.pid}.tmp"
    File.open(tmp_file, 'w') { |f| f.write data }
    File.rename(tmp_file, target_file)
  end

  # Return a new Hash with all keys symbolized
  def symbolize_keys(hash)
    symbolized_hash = {}
    hash.each { |k, v| symbolized_hash[k.to_sym] = v }
    symbolized_hash
  end

  # Return a new Hash with only they white listed keys
  def slice(hash, *white_listed_keys)
    sliced_hash = {}
    white_listed_keys.each do |key|
      sliced_hash[key] = hash[key] if hash.has_key?(key)
    end
    sliced_hash
  end
end
