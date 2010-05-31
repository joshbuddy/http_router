class HttpRouter
  class Root < Node
    def add_path(path)
      node = path.parts.inject(self) { |node, part| node.add(part) }
      node
    end

    def find(request)
      path = request.path_info.dup
      parts = router.split(path)
      parts << '' if path[path.size - 1] == ?/
      params = []
      process_response(
        find_on_parts(request, parts, params),
        parts,
        params, 
        request
      )
    end
    
    private
    def process_response(node, parts, params, request)
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
        nil
      end
    end
  end
end