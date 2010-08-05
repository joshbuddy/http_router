# -*- encoding: utf-8 -*-

require File.join(File.dirname(__FILE__), 'lib', 'http_router', 'version')

Gem::Specification.new do |s|
  s.name = 'http_router'
  s.version = HttpRouter::VERSION
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Joshua Hull"]
  s.summary = "A kick-ass HTTP router for use in Rack & Sinatra"
  s.description = "This library allows you to recognize and build URLs in a Rack application. As well it contains an interface for use within Sinatra."
  s.email = %q{joshbuddy@gmail.com}
  s.extra_rdoc_files = ['README.rdoc']
  s.files = `git ls-files`.split("\n")
  s.homepage = %q{http://github.com/joshbuddy/http_router}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.test_files = `git ls-files`.split("\n").select{|f| f =~ /^spec/}
  s.rubyforge_project = 'http_router'

  # dependencies
  s.add_runtime_dependency 'rack',        '>=1.0'
  s.add_runtime_dependency 'url_mount',   '>=0.2.1'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'sinatra'
  s.add_development_dependency 'rbench'
  s.add_development_dependency 'tumbler', ">= 0.0.11"

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

