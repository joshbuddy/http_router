# encoding: utf-8
require 'bundler'
Bundler::GemHelper.install_tasks
# Rake::Task['release'].enhance([:test, :release_js]) FIXME, this just doesn't work.

task :default => [:test]

task :release_js do
  $: << 'lib'
  require 'http_router/version'
  File.open('js/package.json', 'w') do |f|
    f << <<-EOT
{
  "name": "http_router",
  "description": "URL routing and generation in js",
  "author": "Joshua Hull <joshbuddy@gmail.com>",
  "version": "#{HttpRouter::VERSION}",
  "directories": {
    "lib" : "./lib/http_router"
  },
  "main": "lib/http_router"
}
  EOT
  end
  sh "cd js && npm publish"
  `git commit js/package.json -m'bumped js version'`
end

test_tasks = ['test:generation', 'test:recognition', 'test:integration', 'test:examples', 'test:rdoc_examples']
#test_tasks << 'test:js' if `which coffee && which node` && $?.success?
desc "Run all tests"
task :test => test_tasks

desc "Clean things"
task :clean do
  sh 'find . -name "*.rbc" | xargs rm'
  sh 'rm -rf pkg'
end

namespace :test do
  desc "Run integration tests"
  task :integration do
    $: << 'lib'
    require 'http_router'
    require './test/helper'
    Dir['./test/**/test_*.rb'].each { |test| require test }
  end

  desc "Run js tests"
  task :js do
    sh "coffee -c js/test/test.coffee"
    sh "coffee -c js/lib/http_router.coffee"
    sh "node js/test/test.js"
  end

  desc "Run generic recognition tests"
  task :recognition do
    $: << 'lib'
    require 'http_router'
    require './test/recognition'
  end

  desc "Run generic recognition tests"
  task :generation do
    $: << 'lib'
    require 'http_router'
    require './test/generation'
  end

  desc "Run example tests"
  task :examples do
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
            raise "#{c} produced #{`#{c[1, c.size]} 2>&1`}" unless $?.success?
          when /^=> ?(.*)/
            c = $1
            raise "out was nil" if out.nil?
            test = out.shift
            c.gsub!(/Last-Modified:.*?[\r\n]*/)
            test.gsub!(/Last-Modified:.*?[\r\n]*/)
            raise "expected #{c.inspect}, received #{test.inspect}" unless c.strip == test.strip
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
  desc "rdoc examples"
  task :rdoc_examples do
    $: << 'lib'
    require 'http_router'
    in_example = false
    examples = []
    STDOUT.sync = true
    current_example = ''
    rb_files = Dir['./lib/**/*.rb']
    puts "Scanning #{rb_files * ', '}"
    rb_files.each do |file|
      lines = File.read(file).split(/\n/)
      lines.each do |line|
        if line[/^\s*#(.*)/] # comment
          line = $1.strip
          case line
          when /^example:/i then in_example = true
          when /^(?:# )?=+> (.*)/
            expected = $1.strip
            msg = expected.dup
            msg << " was expected to be "
            msg << "\#{__example_runner.inspect}"
            current_example << "raise \"#{msg.gsub('"', '\\"')}\" unless __example_runner.strip == #{expected}\n" if in_example
          when ''
            unless current_example.empty?
              examples << current_example
              current_example = ''
            end
            in_example = false
          else
            current_example << "__example_runner = (" << line << ")\n" if in_example
          end
        else
          unless current_example.empty?
            examples << current_example
            current_example = ''
          end
          in_example = false
        end
      end
    end
    puts "Running #{examples.size} example#{'s' if examples.size != 1}"
    examples.each do |example|
      print "."
      eval(example)
    end
    puts " ✔"
  end
end

require 'rake/rdoctask'
desc "Generate documentation"
Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
  rd.rdoc_dir = 'rdoc'
end

require 'code_stats'
CodeStats::Tasks.new
