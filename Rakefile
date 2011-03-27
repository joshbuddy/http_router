require 'rubygems'
require 'bundler'
require 'code_stats'

desc "Run tests"
task :test do
  $: << 'lib'
  require 'http_router'
  require './test/helper'
  Dir['./test/**/test_*.rb'].each { |test| require test }
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

task :test_examples do
  $: << 'lib'
  require 'http_router'
  require 'thin'
  Dir['./examples/**/*.ru'].each do |example|
    print "running example #{example}..."
    comments = File.read(example).split(/\n/).select{|l| l[0] == ?#}
    pid = nil
    Thin::Logging.silent = true
    begin
      pid = fork {
        code = "Proc.new { \n#{File.read(example)}\n }"
        r = eval(code, binding, example, 2)
        Thin::Server.start(:signals => false, &r)
      }
      sleep 0.5
      out = nil
      assertion_count = 0
      comments.each do |c|
        c.gsub!(/^# ?/, '')
        case c
        when /^\$/
          out = `#{c[1, c.size]} 2>/dev/null`.split(/\n/)
          raise "#{c} produced #{out}" unless $?.success?
        when /^=> ?(.*)/
          c = $1
          raise "out was nil" if out.nil?
          test = out.shift
          raise "excepted #{c.inspect}, recieved #{test.inspect}" unless c.strip == test.strip
          assertion_count += 1
        end
      end
      raise "no assertions were raised in #{example}" if assertion_count.zero?
      puts "✔"
    ensure
      Process.kill('HUP', pid) if pid
    end
  end
end