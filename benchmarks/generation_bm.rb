require 'rubygems'
require 'rbench'
#require 'lib/usher'
require 'usher'

u = Usher.new(:generator => Usher::Util::Generators::URL.new)
u.add_route('/simple')                                                                                     .name(:simple)
u.add_route('/simple/:variable')                                                                           .name(:one_variable)
u.add_route('/simple/:var1/:var2/:var3')                                                                   .name(:three_variables)
u.add_route('/simple/:v1/:v2/:v3/:v4/:v5/:v6/:v7/:v8')                                                     .name(:eight_variables)
u.add_route('/with_condition/:cond1/:cond2', :requirements => {:cond1 => /^\d+$/, :cond2 => /^[a-z]+$/})   .name(:two_conditions)
u.add_route('/with_condition/{:cond1,^\d+$}/{:cond2,^[a-z]+$}')                                            .name(:two_implicit_conditions)
#u.add_route('/blog/:page', :default_values => {:page => 1})                                                .name(:default_value)
#u.add_route('/blog', :default_values => {:page => 1})                                                      .name(:default_value_not_as_variable)
#
TIMES = 50_000

RBench.run(TIMES) do

  group "named" do
    report "simple" do
      u.generator.generate(:simple)
    end

    report "one variable (through array)" do
      u.generator.generate(:one_variable, 'variable')
    end

    report "one variable (through hash)" do
      u.generator.generate(:one_variable, :variable => 'variable')
    end

    report "three variable (through array)" do
      u.generator.generate(:three_variables, ['var1', 'var2', 'var3'])
    end

    report "three variable (through hash)" do
      u.generator.generate(:three_variables, :var1 => 'var1', :var2 => 'var2', :var3 => 'var3')
    end

    report "eight variable (through array)" do
      u.generator.generate(:eight_variables, ['var1', 'var2', 'var3', 'var4', 'var5', 'var6', 'var7', 'var8'])
    end

    report "eight variable (through hash)" do
      u.generator.generate(:eight_variables, :v1 => 'var1', :v2 => 'var2', :v3 => 'var3', :v4 => 'var4', :v5 => 'var5', :v6 => 'var6', :v7 => 'var7', :v8 => 'var8')
    end

    report "three variable + three extras" do
      u.generator.generate(:three_variables, :var1 => 'var1', :var2 => 'var2', :var3 => 'var3', :var4 => 'var4', :var5 => 'var5', :var6 => 'var6')
    end

    report "three variable + five extras" do
      u.generator.generate(:three_variables, :var1 => 'var1', :var2 => 'var2', :var3 => 'var3', :var4 => 'var4', :var5 => 'var5', :var6 => 'var6', :var7 => 'var7', :var8 => 'var8')
    end

  end

  #group "defaults" do
  #  report "default variable" do
  #    u.generator.generate(:default_value)
  #  end
  #
  #  report "default variable not represented in path" do
  #    u.generator.generate(:default_value_not_as_variable)
  #  end
  #
  #
  #end


end
puts `ps -o rss= -p #{Process.pid}`.to_i