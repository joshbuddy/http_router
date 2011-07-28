require 'json'
require "#{File.dirname(__FILE__)}/generic"
class GenerationTest < AbstractTest
  def run_tests
    @tests.map(&:case).each do |(expected_result, name, args)|
      args = [args] unless args.is_a?(Array)
      args.compact!
      args.map!{|a| a.is_a?(Hash) ? Hash[a.map{|k,v| [k.to_sym, v]}] : a }
      result = begin
        @router.url(name.to_sym, *args)
      rescue HttpRouter::InvalidRouteException
        nil
      rescue HttpRouter::MissingParameterException
        nil
      end
      error("Result #{result.inspect} did not match expectation #{expected_result.inspect}") unless result == expected_result
    end
    print '.'
  end
end

GenerationTest.run("#{File.dirname(__FILE__)}/common/generate.txt")
