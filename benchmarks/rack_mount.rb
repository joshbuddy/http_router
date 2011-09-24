require 'rubygems'
require 'rbench'
require 'rack'
require 'rack/mount'
#require '../usher/lib/usher'
$: << 'lib'
require 'http_router'

set = Rack::Mount::RouteSet.new do |set|
  set.add_route(proc{|env| [200, {'Content-type'=>'text/html'}, []]}, {:path => '/simple'}, {}, :simple)
  set.add_route(proc{|env| [200, {'Content-type'=>'text/html'}, []]}, {:path => '/simple/again'}, {}, :again)
  set.add_route(proc{|env| [200, {'Content-type'=>'text/html'}, []]}, {:path => %r{/simple/(.*?)}}, {}, :more)
end

#u = Usher::Interface.for(:rack)
#u.add('/simple').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
#u.add('/simple/again').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
#u.add('/dynamic/anything').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})

TIMES = 50_000

simple_env = Rack::MockRequest.env_for('/simple')
simple2_env = Rack::MockRequest.env_for('/simple/again')
dynamic_env = Rack::MockRequest.env_for('/simple/something')


  RBench.run(TIMES) do

    report "2 levels, static" do
      set.call(simple_env).first == 200 or raise
    end

    report "4 levels, static" do
      set.call(simple2_env).first == 200 or raise
    end

    report "4 levels, static" do
      set.call(dynamic_env).first == 200 or raise
    end

  end
