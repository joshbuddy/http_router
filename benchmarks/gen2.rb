require 'rubygems'
require 'rbench'
#require 'lib/usher'
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'http_router'

u = HttpRouter.new
u.add('/simple')                                                                                     .name(:simple).to{}
u.add('/simple/:variable')                                                                           .name(:one_variable).to{}
u.add('/simple/:var1/:var2/:var3')                                                                   .name(:three_variables).to{}
u.add('/simple/:v1/:v2/:v3/:v4/:v5/:v6/:v7/:v8')                                                     .name(:eight_variables).to{}
u.add('/with_condition/:cond1/:cond2').matching(:cond1 => /^\d+$/, :cond2 => /^[a-z]+$/)             .name(:two_conditions).to{}

TIMES = 50_000

RBench.run(TIMES) do

  group "named" do
    report "simple" do
      u.url(:simple)
    end

    report "one variable (through array)" do
      u.url(:one_variable, 'variable')
    end

    report "one variable (through hash)" do
      u.url(:one_variable, :variable => 'variable')
    end

    report "three variable (through array)" do
      u.url(:three_variables, 'var1', 'var2', 'var3')
    end

    report "three variable (through hash)" do
      u.url(:three_variables, :var1 => 'var1', :var2 => 'var2', :var3 => 'var3')
    end

    report "eight variable (through array)" do
      u.url(:eight_variables, 'var1', 'var2', 'var3', 'var4', 'var5', 'var6', 'var7', 'var8')
    end

    report "eight variable (through hash)" do
      u.url(:eight_variables, :v1 => 'var1', :v2 => 'var2', :v3 => 'var3', :v4 => 'var4', :v5 => 'var5', :v6 => 'var6', :v7 => 'var7', :v8 => 'var8')
    end

    report "three variable + three extras" do
      u.url(:three_variables, :var1 => 'var1', :var2 => 'var2', :var3 => 'var3', :var4 => 'var4', :var5 => 'var5', :var6 => 'var6')
    end

    report "three variable + five extras" do
      u.url(:three_variables, :var1 => 'var1', :var2 => 'var2', :var3 => 'var3', :var4 => 'var4', :var5 => 'var5', :var6 => 'var6', :var7 => 'var7', :var8 => 'var8')
    end
  end

end

puts `ps -o rss= -p #{Process.pid}`.to_i