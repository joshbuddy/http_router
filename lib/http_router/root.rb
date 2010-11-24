class HttpRouter
  class Root < Node
    class AlternativeRequestMethods < Array
      attr_accessor :request_method_found
    end
    
    def add_path(path)
      node = path.parts.inject(self) { |node, part| node.add(part) }
      node
    end

    def recognize(request)
      call(request, :nocall)
    end

    def call(request, action = :call)
      request = ::Rack::Request.new(request) if request.is_a?(Hash)
      catch(:response) { find_on_parts(request, get_parts(request), action) } || construct_unmatched(request)
    end

    def construct_unmatched(request)
      alternate_methods = (router.request_methods_specified - [request.request_method]).select do |alternate_method|
        test_request = ::Rack::Request.new(request.env.dup)
        test_request.env['REQUEST_METHOD'] = alternate_method
        catch(:response) { find_on_parts(test_request, get_parts(request), :nocall) }
      end
      alternate_methods.empty? ? nil : ::Rack::Response.new("Method not found", 405, {"Allow" => alternate_methods.join(", ")}).finish
    end

    def get_parts(request)
      parts = router.split(request.path_info)
      parts << '' if request.path_info.size > 1 && request.path_info[-1] == ?/
      parts
    end
  end
end