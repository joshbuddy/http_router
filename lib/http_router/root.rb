class HttpRouter
  class Root < Node
    def add_path(path)
      node = path.parts.inject(self) { |node, part| node.add(part) }
      if path.extension
        node = node.add_extension(path.extension)
      end
      node
    end

    def find(request)
      path = request.path_info.dup
      extension = extract_extension(path)
      parts = router.split(path)
      parts << '' if path[path.size - 1] == ?/
      params = []
      process_response(
        find_on_parts(request, parts, extension, params),
        parts,
        extension,
        params, 
        request
      )
    end
    
    private
    def process_response(node, parts, extension, params, request)
      if node.respond_to?(:matched?) && !node.matched?
        node
      elsif node && node.value
        if parts.empty?
          post_match(node.value, params, extension, request.path_info)
        elsif node.value.route.partially_match?
          rest = '/' << parts.join('/') << (extension ? ".#{extension}" : '')
          post_match(node.value, params, nil, request.path_info[0, request.path_info.size - rest.size], rest)
        else
          nil
        end
      else
        nil
      end
    end

    def extract_extension(path)
      if path.gsub!(/\.([^\/\.]+)$/, '')
        extension = $1
      else
        nil
      end
    end

    def post_match(path, params, extension, matched_path, remaining_path = nil)
      if path.route.partially_match? || path.matches_extension?(extension)
        Response.matched(path, params, extension, matched_path, remaining_path)
      else
        nil
      end
    end
  end
end