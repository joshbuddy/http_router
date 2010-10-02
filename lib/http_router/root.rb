class HttpRouter
  class Root < Node
    class AlternativeRequestMethods < Array
      attr_accessor :request_method_found
    end
    
    def add_path(path)
      node = path.parts.inject(self) { |node, part| node.add(part) }
      node
    end

    def find(request)
      routes = []
      node, parts, params = catch(:match) { find_on_parts(request, get_parts(request), [], routes) }
      if !routes.empty?
        routes.map { |node, parts, params| process_response(node, parts, params, request) }
      elsif node
        process_response(node, parts, params, request)
      elsif !router.request_methods_specified.empty?
        alternate_methods = (router.request_methods_specified - [request.request_method]).select do |alternate_method|
          test_request = request.dup
          test_request.env['REQUEST_METHOD'] = alternate_method
          routes = []
          catch(:match) { find_on_parts(test_request, get_parts(request), [], routes) } || !routes.empty?
        end
        alternate_methods.empty? ? nil : Response.unmatched(405, {"Allow" => alternate_methods.join(", ")})
      else
        nil
      end
    end

    def get_parts(request)
      parts = router.split(request.path_info.dup)
      parts << '' if request.path_info[-1] == ?/
      parts
    end

    private
    def process_response(node, parts, params, request)
      if parts.nil? || parts.empty?
        Response.matched(node.value, params, request.path_info)
      elsif node.value.route.partially_match?
        rest = '/' << parts.join('/')
        Response.matched(node.value, params, request.path_info[0, request.path_info.size - rest.size], rest)
      end
    end
  end
end