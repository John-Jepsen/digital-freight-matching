# -*- encoding: utf-8 -*-
# stub: yabeda-sidekiq 0.12.0 ruby lib

Gem::Specification.new do |s|
  s.name = "yabeda-sidekiq".freeze
  s.version = "0.12.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/yabeda-rb/yabeda-sidekiq/issues", "changelog_uri" => "https://github.com/yabeda-rb/yabeda-sidekiq/blob/master/CHANGELOG.md", "homepage_uri" => "https://github.com/yabeda-rb/yabeda-sidekiq", "source_code_uri" => "https://github.com/yabeda-rb/yabeda-sidekiq" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Andrey Novikov".freeze]
  s.bindir = "exe".freeze
  s.date = "2024-03-08"
  s.description = "Prometheus exporter for easy collecting most important of your Sidekiq metrics".freeze
  s.email = ["envek@envek.name".freeze]
  s.homepage = "https://github.com/yabeda-rb/yabeda-sidekiq".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Extensible Prometheus exporter for monitoring your Sidekiq".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<anyway_config>.freeze, [">= 1.3", "< 3"])
  s.add_runtime_dependency(%q<sidekiq>.freeze, [">= 0"])
  s.add_runtime_dependency(%q<yabeda>.freeze, ["~> 0.6"])
  s.add_development_dependency(%q<activejob>.freeze, [">= 6.0"])
  s.add_development_dependency(%q<bundler>.freeze, ["~> 2.0"])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.0"])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0"])
end
