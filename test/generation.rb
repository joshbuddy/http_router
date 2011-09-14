require 'json'
require "#{File.dirname(__FILE__)}/generic"
class GenerationTest < AbstractTest
  def run_tests
    @tests.map(&:case).each do |(expected_result, name, oargs)|
      oargs = [oargs] unless oargs.is_a?(Array)
      oargs.compact!
      oargs.map!{|a| a.is_a?(Hash) ? Hash[a.map{|k,v| [k.to_sym, v]}] : a }
      [[:path, ''], [:url_ns, '://localhost'], [:url, 'http://localhost']].each do |(meth, prefix)|
        args = oargs.map{|o| o.dup rescue o}
        result = begin
          path = @router.send(meth, name.to_sym, *args.dup)
          path
        rescue HttpRouter::InvalidRouteException
          nil
        rescue HttpRouter::MissingParameterException
          nil
        end
        error("Result #{result.inspect} did not match expectation #{expected_result.inspect}") unless result == (expected_result ? prefix + expected_result : expected_result)
      end
    end
    print '.'
  end
end

GenerationTest.run("#{File.dirname(__FILE__)}/common/generate.txt")
