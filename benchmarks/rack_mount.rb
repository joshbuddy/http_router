require 'rubygems'
require 'rbench'
require 'rack'
require 'rack/mount'
#require '../usher/lib/usher'
require 'lib/http_router'

set = Rack::Mount::RouteSet.new do |set|
  set.add_route(proc{|env| [200, {'Content-type'=>'text/html'}, []]}, {:path => '/simple'}, {}, :simple)
  set.add_route(proc{|env| [200, {'Content-type'=>'text/html'}, []]}, {:path => '/simple/again'}, {}, :again)
  set.add_route(proc{|env| [200, {'Content-type'=>'text/html'}, []]}, {:path => '/dynamic/:variable'}, {}, :variable)
end

#u = Usher::Interface.for(:rack)
#u.add('/simple').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
#u.add('/simple/again').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
#u.add('/dynamic/anything').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})

hr = HttpRouter.new
hr.add('/simple').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
hr.add('/simple/again').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})
hr.add('/dynamic/anything').to(proc{|env| [200, {'Content-type'=>'text/html'}, []]})

TIMES = 50_000

simple_env = Rack::MockRequest.env_for('/simple')
simple2_env = Rack::MockRequest.env_for('/simple/again')
simple_and_dynamic_env = Rack::MockRequest.env_for('/dynamic/anything')

3.times do

  RBench.run(TIMES) do

    report "2 levels, static" do
      set.url(simple_env, :simple)
    end

    report "4 levels, static" do
      set.url(simple_env, :again)
    end

    report "4 levels, 1 dynamic" do
      set.url(simple_env, :variable, {:variable => 'onemore'})
    end

  end
end
