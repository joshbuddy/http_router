class HttpRouter
  class Node
    class Glob < Node
      alias_method :node_to_code, :to_code
      def usable?(other)
        other.class == self.class
      end

      def to_code
        id = root.next_counter
        "request.params << (globbed_params#{id} = [])
          until request.path.empty?
            globbed_params#{id} << request.path.shift
            #{super}
          end
          request.path[0,0] = globbed_params#{id}"
      end
    end
  end
end