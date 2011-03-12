class HttpRouter
  class Node
    class SpanningRegex < Regex
      def [](request)
        whole_path = join_whole_path(request)
        if match = @matcher.match(whole_path) and match.begin(0).zero?
          request = request.clone
          add_params(request, match)
          remaining_path = whole_path[match[0].size + (whole_path[match[0].size] == ?/ ? 1 : 0), whole_path.size]
          request.path = remaining_path.split('/')
          node_lookup(request)
        end
      end
    end
  end
end