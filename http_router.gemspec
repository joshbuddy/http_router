# -*- encoding: utf-8 -*-

require 'tumbler/gemspec'

Gem::Specification.new do |s|
  s.name = Tumbler::Gemspec.name
  s.version = Tumbler::Gemspec.version

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Joshua Hull"]
  s.date = Tumbler::Gemspec.date
  s.description = %q{A kick-ass HTTP router for use in Rack & Sinatra}
  s.email = %q{joshbuddy@gmail.com}
  s.extra_rdoc_files = Tumbler::Gemspec.files('README.rdoc')
  s.files = Tumbler::Gemspec.files
  s.homepage = %q{http://github.com/joshbuddy/http_router}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{A kick-ass HTTP router for use in Rack & Sinatra}
  s.test_files = Tumbler::Gemspec.files(/^spec/)

  # dependencies
  Tumbler::Gemspec.inject_dependencies(s)

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

