# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'torm/version'

Gem::Specification.new do |spec|
  spec.name        = 'torm'
  spec.version     = Torm::VERSION
  spec.authors     = ['Wes Oldenbeuving']
  spec.email       = ['narnach@gmail.com']
  spec.summary     = %q{Ruby rules engine}
  spec.description = %q{Rules engine. Named after the Forgotten Realms god of Law.}
  spec.homepage    = ''
  spec.license     = 'MIT'

  spec.files                 = `git ls-files -z`.split("\x0")
  spec.executables           = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files            = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths         = ['lib']

  # Ruby 2.1 introduces required named keywords
  spec.required_ruby_version = '>= 2.1.0'

  # MultiJson follow Semantic Versioning, so any 1.x should work.
  spec.add_dependency 'multi_json', '~> 1.0'

  # Defaults from generating the gemspec
  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'codeclimate-test-reporter'
end
