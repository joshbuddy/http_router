require 'rubygems'
require 'bundler'
require 'code_stats'

desc "Run tests"
task :test => [:spec] do
  $: << 'lib'
  require 'http_router'
  require 'test/helper'
  Dir['test/**/test_*.rb'].each { |test| require test }
end

require 'rspec/core/rake_task'
 
desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  #t.rspec_opts = %w(--options spec/spec.opts)
  #t.ruby_opts  = %w(-w)
end
require 'rake/rdoctask'
desc "Generate documentation"
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
  rd.rdoc_dir = 'rdoc'
end

Bundler::GemHelper.install_tasks
CodeStats::Tasks.new(:reporting_depth => 3)
