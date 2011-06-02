class HttpRouter
  class Node
    class Glob < Node
      alias_method :node_to_code, :to_code
      def usable?(other)
        other.class == self.class
      end

      def to_code
        "request.params << (globbed_params#{depth} = [])
          until request.path.empty?
            globbed_params#{depth} << request.path.shift
            #{super}
          end
          request.path[0,0] = globbed_params#{depth}"
      end
    end
  end
end