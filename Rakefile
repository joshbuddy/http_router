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
