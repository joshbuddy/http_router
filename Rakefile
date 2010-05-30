begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "http_router"
    s.description = s.summary = "A kick-ass HTTP router for use in Rack & Sinatra"
    s.email = "joshbuddy@gmail.com"
    s.homepage = "http://github.com/joshbuddy/http_router"
    s.authors = ["Joshua Hull"]
    s.files = FileList["[A-Z]*", "{lib,spec}/**/*"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

require 'spec'
require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts ||= []
  t.ruby_opts << "-rrubygems"
  t.ruby_opts << "-Ilib"
  t.ruby_opts << "-rhttp_router"
  t.ruby_opts << "-rspec/spec_helper"
  t.spec_opts << "--options" << "spec/spec.opts"
  t.spec_files = FileList['spec/**/*_spec.rb']
end

begin
  require 'code_stats'
  CodeStats::Tasks.new
rescue LoadError
end
