require "#{File.dirname(__FILE__)}/generic"
class RecognitionTest < AbstractTest
  def run_tests
    @tests.map(&:case).each do |(name, req, params)|
      env = case req
      when String
        Rack::MockRequest.env_for(req)
      when Hash
        e = Rack::MockRequest.env_for(req['path'])
        e['REQUEST_METHOD'] = req['method'] if req.key?('method')
        e['rack.url_scheme'] = req['scheme'] if req.key?('scheme')
        e
      end
      response = @router.call(env)
      case name
      when nil
        error("Expected no response") unless response.first == 404
      when Array
        name.each_with_index do |part, i|
          case part
          when Hash then part.keys.all? or error("#{part.inspect} didn't match #{response[i].inspect}")
          else           part == response[i] or error("#{part.inspect} didn't match #{response[i].inspect}")
          end
        end
      else
        error("Expected #{name} for #{req.inspect} got #{response.inspect}") unless response.last == [name]
      end
      env['router.params'] ||= {}
      params ||= {}
      if params['PATH_INFO']
        path_info = params.delete("PATH_INFO")
        error("path_info #{env['PATH_INFO'].inspect} is not #{path_info.inspect}") unless path_info == env['PATH_INFO']
      end

      env['router.params'].keys.each do |k|
        p_v = params.delete(k.to_s)
        v = env['router.params'].delete(k.to_sym)
        error("I got #{p_v.inspect} but expected #{v.inspect}") unless p_v == v
      end
      error("Left over expectations: #{params.inspect}") unless params.empty?
      error("Left over matched params: #{env['router.params'].inspect}") unless env['router.params'].empty?
    end
    print '.'
  end
end

RecognitionTest.run("#{File.dirname(__FILE__)}/common/recognize.txt")
RecognitionTest.run("#{File.dirname(__FILE__)}/common/http_recognize.txt")
