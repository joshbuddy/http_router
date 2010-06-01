require 'rubygems'
require 'rbench'
require 'usher'

u = Usher.new(:generator => Usher::Util::Generators::URL.new)
u.add_route('/simple')
u.add_route('/simple/again')
u.add_route('/simple/again/and/again')
u.add_route('/dynamic/:variable')
u.add_route('/rails/:controller/:action/:id')
u.add_route('/greedy/{!greed,.*}')

TIMES = 50_000

RBench.run(TIMES) do

  report "2 levels, static" do
    u.recognize_path('/simple')
  end

  report "4 levels, static" do
    u.recognize_path('/simple/again')
  end

  report "8 levels, static" do
    u.recognize_path('/simple/again/and/again')
  end

  report "4 levels, 1 dynamic" do
    u.recognize_path('/dynamic/anything')
  end

  report "8 levels, 3 dynamic" do
    u.recognize_path('/rails/controller/action/id')
  end

  report "4 levels, 1 greedy" do
    u.recognize_path('/greedy/controller/action/id')
  end

end
