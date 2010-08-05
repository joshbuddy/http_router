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
      path = request.path_info.dup
      parts = router.split(path)
      parts << '' if path[path.size - 1] == ?/
      params = []
      alternate_request_methods = AlternativeRequestMethods.new
      alternate_request_methods.request_method_found = false
      process_response(
        find_on_parts(request, parts, params, alternate_request_methods),
        parts,
        params, 
        request,
        alternate_request_methods
      )
    end
    
    private
    def process_response(node, parts, params, request, alternate_request_methods)
      if node.respond_to?(:matched?) && !node.matched?
        node
      elsif node && node.value
        if parts.empty?
          Response.matched(node.value, params, request.path_info)
        elsif node.value.route.partially_match?
          rest = '/' << parts.join('/')
          Response.matched(node.value, params, request.path_info[0, request.path_info.size - rest.size], rest)
        else
          nil
        end
      else
        if alternate_request_methods.request_method_found or alternate_request_methods.empty?
          nil
        else
          Response.unmatched(405, {"Allow" => alternate_request_methods.uniq.join(", ")})
        end
      end
    end
  end
end