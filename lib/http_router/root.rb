class HttpRouter
  class Root < Node
    def initialize(base)
      @base = base
      reset!
    end

    def add_path(path)
      node = path.parts.inject(self) { |node, part| node.add(part) }
      if path.extension
        node = node.add_extension(path.extension)
      end
      node
    end

    def find(request)
      path = request.path_info.dup
      path.slice!(-1) if @base.ignore_trailing_slash? && path[-1] == ?/
      extension = extract_extension(path)
      parts = @base.split(path)
      parts << '' if path[path.size - 1] == ?/

      params = []
      if current_node = process_parts(parts, extension, params)
        current_node = current_node.find_on_request_methods(request)
      end
      
      process_response(current_node, parts, extension, params, request)
    end
    
    private
    
    def process_parts(parts, extension, params)
      current_node = self
      while current_node
        if current_node.extension_node && extension && parts.empty?
          parts << extension
          current_node = current_node.extension_node
        end
        break if current_node.nil? || (current_node.value && current_node.value.route.partially_match?) || parts.empty?
        unless current_node.linear.empty?
          whole_path = parts.join('/')
          next_node = current_node.linear.find do |(tester, node)|
            if tester.is_a?(Regexp) and match = whole_path.match(tester)
              whole_path.slice!(0,match[0].size)
              parts.replace(@base.split(whole_path))
              node
            elsif new_params = tester.matches(parts, whole_path)
              params << new_params
              node
            else
              nil
            end
          end
          if next_node
            current_node = next_node.last
            next
          end
        end
        if match = current_node.lookup[parts.first]
          parts.shift
          current_node = match
        elsif current_node.catchall
          params << current_node.catchall.variable.matches(parts, whole_path)
          parts.shift
          current_node = current_node.catchall
        elsif parts.size == 1 && parts.first == '' && current_node && (current_node.value && current_node.value.route.trailing_slash_ignore?)
          parts.shift
        elsif current_node.request_node
          break
        else
          current_node = nil
        end
      end
      current_node
    end

    def process_response(node, parts, extension, params, request)
      if node.is_a?(RoutingError)
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
        Response.new(path, params, extension, matched_path, remaining_path)
      else
        nil
      end
    end
  end
end
