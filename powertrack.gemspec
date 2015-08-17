# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'powertrack/version'

Gem::Specification.new do |spec|
  spec.name          = 'powertrack'
  spec.version       = PowerTrack::VERSION
  spec.authors       = ['Laurent Farcy', 'Eric Wendelin', 'Ryan Weald']
  spec.email         = ['laurent.farcy@ecairn.com', 'me@eriwen.com', 'ryan@weald.com']
  spec.summary       = %q{Powertrack-rb is a gem used to develop GNIP PowerTrack streaming clients.}
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/ecairn/powertrack-rb'
  spec.license       = 'MIT license'
  spec.required_ruby_version = '~> 1.9'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.3'
  spec.add_development_dependency 'minitest', '~> 5.5'
  spec.add_development_dependency 'ruby-prof', '~> 0.15'

  spec.add_dependency 'multi_json', '~> 1.11'
  spec.add_dependency 'eventmachine', '~> 1.0'
  spec.add_dependency 'em-http-request', '~> 1.1'
  spec.add_dependency 'exponential-backoff',  '~> 0.0.2'
  spec.add_dependency 'void_logger',  '~> 0.1'
end
