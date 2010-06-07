# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{http_router}
  s.version = File.read(File.join(File.dirname(__FILE__), 'VERSION')).strip

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Joshua Hull"]
  s.date = %q{2010-05-30}
  s.description = %q{A kick-ass HTTP router for use in Rack & Sinatra}
  s.email = %q{joshbuddy@gmail.com}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = `git ls-files`.split("\n")
  s.homepage = %q{http://github.com/joshbuddy/http_router}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{A kick-ass HTTP router for use in Rack & Sinatra}
  s.test_files = `git ls-files spec`.split("\n")

  # dependencies
  s.add_dependency "rack",      ">= 1.0.0"
  s.add_dependency "url_mount", ">=0.2"

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

