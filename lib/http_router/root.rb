class HttpRouter
  class Root < Node
    def initialize(base)
      @base = base
      reset!
    end

    def find(request)
      path = request.path_info.dup
      path.slice!(-1) if @base.ignore_trailing_slash? && path[-1] == ?/
      path.gsub!(/\.([^\/\.]+)$/, '')
      extension = $1
      parts = @base.split(path)
      parts << '' if path[path.size - 1] == ?/

      current_node = self
      params = []
      while current_node
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
      
      if current_node && current_node.request_node
        current_node = current_node.request_node
        while current_node
          previous_node = current_node
          break if current_node.nil? || current_node.is_a?(RoutingError) || current_node.value
          request_value = request.send(current_node.request_method)
          unless current_node.linear.empty?
            next_node = current_node.linear.find do |(regexp, node)|
              regexp === request_value
            end
            if next_node
              current_node = next_node.last
              next
            end
          end
          current_node = current_node.lookup[request_value] || current_node.catchall
          if current_node.nil?
            current_node = previous_node.request_method == :request_method ? RoutingError.new(405, {"Allow" => previous_node.lookup.keys.join(", ")}) : nil
          else
            current_node
          end
        end
      end
      if current_node.is_a?(RoutingError)
        current_node
      elsif current_node && current_node.value
        if parts.empty?
          post_match(current_node.value, params, extension, request.path_info)
        elsif current_node.value.route.partially_match?
          rest = '/' << parts.join('/') << (extension ? ".#{extension}" : '')
          
          post_match(current_node.value, params, nil, request.path_info[0, request.path_info.size - rest.size], rest)
        else
          nil
        end
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
