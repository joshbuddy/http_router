require 'json'

class AbstractTest
  def self.run(file)
    contents = File.read(file)
    tests = []
    test = nil
    num = 0
    contents.each_line do |line|
      begin
        case line
        when /^#/, /^\s*$/
          # skip
        when /^(  |\t)/
          test.add_test(line, num)
        else
          if test.nil? || !test.tests.empty?
            tests << test if test
            test = new(file)
          end
          test.add_routes(line, num)
        end
      rescue
        warn "There was a problem with #{num}:#{line}"
        raise
      end
      num += 1
    end
    tests << test

    puts "Running tests (#{name}) (Routes: #{tests.size}, Tests: #{tests.inject(0){|s, t| s+=t.tests.size}})..."
    tests.each(&:invoke)
    puts "\ndone!"
  end

  Info = Struct.new(:case, :original_line, :num)
  
  attr_reader :routes, :tests
  def initialize(file)
    @tests = []
    @routes = Info.new([], "", 0)
  end

  def error(msg)
    raise("Error in case: #{@routes.original_line.strip}:#{@routes.num + 1}\n#{msg}")
  end

  def add_test(line, num)
    @tests << Info.new(JSON.parse(line), line, num)
  end

  def add_routes(line, num)
    info = Info.new(JSON.parse(line), line, num)
    error("Routes have already been defined without tests") if info.case.is_a?(Array) && !@routes.case.empty?
    if info.case.is_a?(Array)
      @routes = info
    elsif @routes.case.empty?
      info.case = [info.case]
      @routes = info
    else
      @routes.case << info.case
    end
  end

  def interpret_val(val)
    case val
    when nil
      error("Unable to interpret #{val.inspect}")
    when Hash
      val['regex'] ? Regexp.new(val['regex']) : error("Okay serious, no idea #{val.inspect}")
    else
      val
    end
  end

  def run_tests
    raise
  end

  def invoke
    error("invoke called with no tests or routes") if @tests.empty? || @routes.nil?
    @router = HttpRouter.new
    @routes.case.each do |route_definition|
      error("Too many keys! #{route_definition.keys.inspect}") unless route_definition.keys.size == 1
      route_name, route_properties = route_definition.keys.first, route_definition.values.first
      route = case route_properties
      when String
        @router.add(route_properties)
      when Hash
        opts = {}
        route_path = interpret_val(route_properties.delete("path"))
        if route_properties.key?("conditions")
          opts[:conditions] = Hash[route_properties.delete("conditions").map{|k, v| [k.to_sym, interpret_val(v)]}]
        end
        if route_properties.key?("default")
          opts[:default_values] = Hash[route_properties.delete("default").map{|k, v| [k.to_sym, interpret_val(v)]}]
        end
        route_properties.each do |key, val|
          opts[key.to_sym] = interpret_val(val)
        end
        @router.add(route_path, opts)
      else
        error("Route isn't a String or hash")
      end
      route.name(route_name.to_sym)
      route.to{|env| [200, {"env-to-test" => env.dup}, [route_name]]}
    end
    run_tests
    print '.'
  end
end
