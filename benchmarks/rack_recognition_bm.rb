require 'rubygems'
require 'rbench'
require '../usher/lib/usher'

u = Usher::Interface.for(:rack)
u.add('/simple').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
u.add('/simple/again').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
u.add('/simple/again/and/again').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
u.add('/dynamic/:variable').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
u.add('/rails/:controller/:action/:id').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
u.add('/greedy/{!greed,.*}').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})

TIMES = 50_000

simple_env = Rack::MockRequest.env_for('/simple')
simple2_env = Rack::MockRequest.env_for('/simple/again')
simple3_env = Rack::MockRequest.env_for('/simple/again/and/again')
simple_and_dynamic_env = Rack::MockRequest.env_for('/dynamic/anything')
simple_and_dynamic_env1 = Rack::MockRequest.env_for('/rails/controller/action/id')
simple_and_dynamic_env2 = Rack::MockRequest.env_for('/greedy/controller/action/id')

RBench.run(TIMES) do

  report "2 levels, static" do
    u.call(simple_env).first == 200 or raise
  end

  report "4 levels, static" do
    u.call(simple2_env).first == 200 or raise
  end

  report "8 levels, static" do
    u.call(simple3_env).first == 200 or raise
  end

  report "4 levels, 1 dynamic" do
    u.call(simple_and_dynamic_env).first == 200 or raise
  end

  report "8 levels, 3 dynamic" do
    u.call(simple_and_dynamic_env1).first == 200 or raise
  end

  report "4 levels, 1 greedy" do
    u.call(simple_and_dynamic_env2).first == 200 or raise
  end

end

puts `ps -o rss= -p #{Process.pid}`.to_i