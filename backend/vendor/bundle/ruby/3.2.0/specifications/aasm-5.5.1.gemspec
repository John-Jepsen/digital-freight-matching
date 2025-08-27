# -*- encoding: utf-8 -*-
# stub: aasm 5.5.1 ruby lib

Gem::Specification.new do |s|
  s.name = "aasm".freeze
  s.version = "5.5.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Thorsten Boettger".freeze, "Anil Maurya".freeze]
  s.date = "2025-06-14"
  s.description = "AASM is a continuation of the acts-as-state-machine rails plugin, built for plain Ruby objects.".freeze
  s.email = "aasm@mt7.de, anilmaurya8dec@gmail.com".freeze
  s.homepage = "https://github.com/aasm/aasm".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "State machine mixin for Ruby objects".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<rake>.freeze, [">= 0"])
  s.add_development_dependency(%q<sdoc>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 3"])
  s.add_development_dependency(%q<generator_spec>.freeze, [">= 0"])
  s.add_development_dependency(%q<appraisal>.freeze, [">= 0"])
  s.add_development_dependency(%q<simplecov-cobertura>.freeze, [">= 0"])
  s.add_development_dependency(%q<pry>.freeze, [">= 0"])
end
