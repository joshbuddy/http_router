class HttpRouter
  class Node
    class Variable < Node
      def usable?(other)
        other.class == self.class
      end

      def to_code
        "unless request.path_finished?
          request.params << request.path.shift
          #{super}
          request.path.unshift request.params.pop
        end"
      end
    end
  end
end