# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'powertrack/version'

Gem::Specification.new do |spec|
  spec.name          = 'powertrack'
  spec.version       = PowerTrack::VERSION
  spec.authors       = ['Laurent Farcy', 'Eric Wendelin']
  spec.email         = ['laurent.farcy@ecairn.com', 'me@eriwen.com']
  spec.summary       = %q{Powertrack-rb is a gem used to develop GNIP PowerTrack streaming clients.}
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/ecairn/powertrack-rb'
  spec.license       = 'MIT license.'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.3'
  spec.add_development_dependency 'minitest', '~> 5.5'
  spec.add_development_dependency 'ruby-prof', '~> 0.15'

  spec.add_dependency 'multi_json', '~> 1.11'
  spec.add_dependency 'eventmachine', '~> 1.0.3'
  spec.add_dependency 'em-http-request', '~> 1.1'
end
