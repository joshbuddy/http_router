require 'rubygems'
require 'spec'
require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts ||= []
  t.spec_opts << "--options" << "spec/spec.opts"
  t.spec_files = FileList['spec/**/*_spec.rb']
end

begin
  require 'code_stats'
  CodeStats::Tasks.new
rescue LoadError
end

require 'rake/rdoctask'
desc "Generate documentation"
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
  rd.rdoc_dir = 'rdoc'
end


# automatically added Tumbler tasks

require 'tumbler'
Tumbler.use_rake_tasks
