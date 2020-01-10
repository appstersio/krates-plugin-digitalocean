# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kontena/plugin/digital_ocean'

Gem::Specification.new do |spec|
  spec.name          = "krates-plugin-digitalocean"
  spec.version       = Kontena::Plugin::DigitalOcean::VERSION
  spec.authors       = ["Pavel Tsurbeleu"]
  spec.email         = ["krates@appsters.io"]

  spec.summary       = "Krates DigitalOcean plugin"
  spec.description   = "Krates DigitalOcean plugin"
  spec.homepage      = "https://krates.appsters.io"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|build)/}) }
  spec.require_paths = ["lib"]

  # NOTE: Exclude files not relevant to the plugin
  spec.files        -= %w[ Makefile .dockerignore .travis.yml .gitignore .gitmodules README.md .rspec ]

  spec.add_runtime_dependency 'krates', '~> 1.6'
  spec.add_runtime_dependency 'droplet_kit', '~> 2.2'
  spec.add_runtime_dependency 'activesupport', '~> 4.0'
  spec.add_runtime_dependency 'pastel', '0.7.2'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
end
