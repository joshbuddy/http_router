require 'rubygems'
require 'rbench'

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'http_router'

#require 'http_router'

u = HttpRouter.new

#puts Benchmark.measure {
#  ('aa'..'nn').each do |first|
#    ('a'..'n').each do |second|
#      u.add("/#{first}/#{second}").to {|env| [200, {'Content-type'=>'text/html'}, []]}
#    end
#  end
#  puts "u.routes.size: #{u.routes.size}"
#}

u.add('/').to {|env| [200, {'Content-type'=>'text/html'}, []]}

u.add('/simple').to {|env| [200, {'Content-type'=>'text/html'}, []]}
u.add('/simple/again').to {|env| [200, {'Content-type'=>'text/html'}, []]}
#u.add('/simple/again/and/again').compile.to {|env| [200, {'Content-type'=>'text/html'}, []]}
u.add('/dynamic/:variable').to {|env| [200, {'Content-type'=>'text/html'}, []]}
#u.add('/rails/:controller/:action/:id').compile.to {|env| [200, {'Content-type'=>'text/html'}, []]}
#u.add('/greedy/:greed').matching(:greed => /.*/).compile.to {|env| [200, {'Content-type'=>'text/html'}, []]}
#u.add('/greedy/hey.:greed.html').to {|env| [200, {'Content-type'=>'text/html'}, []]}

#
TIMES = 50_000

#simple_env = 
#simple2_env = 
#simple3_env = Rack::MockRequest.env_for('/simple/again/and/again')
#simple_and_dynamic_env = 
#simple_and_dynamic_env1 = Rack::MockRequest.env_for('/rails/controller/action/id')
#simple_and_dynamic_env2 = Rack::MockRequest.env_for('/greedy/controller/action/id')
#simple_and_dynamic_env3 = Rack::MockRequest.env_for('/greedy/hey.hello.html')
u.call(Rack::MockRequest.env_for('/simple')).first == 200 or raise
5.times {
  RBench.run(TIMES) do

    report "1 levels, static" do
      u.call(Rack::MockRequest.env_for('/')).first == 200 or raise
    end

    report "2 levels, static" do
      u.call(Rack::MockRequest.env_for('/simple')).first == 200 or raise
    end

    report "3 levels, static" do
      u.call(Rack::MockRequest.env_for('/simple/again')).first == 200 or raise
    end

    #report "8 levels, static" do
    #  u.call(simple3_env).first == 200 or raise
    #end

    report "1 static, 1 dynamic" do
      u.call(Rack::MockRequest.env_for('/dynamic/anything')).first == 200 or raise
    end

    #report "8 levels, 3 dynamic" do
    #  u.call(simple_and_dynamic_env1).first == 200 or raise
    #end
    #
    #report "4 levels, 1 greedy" do
    #  u.call(simple_and_dynamic_env2).first == 200 or raise
    #end

  end
}
puts `ps -o rss= -p #{Process.pid}`.to_i