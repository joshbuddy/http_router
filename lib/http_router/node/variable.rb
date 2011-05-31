class HttpRouter
  class Node
    class Variable < Node
      def usuable?(other)
        other.class == self.class
      end

      def to_code(pos)
        indented_code(pos, "
          unless request#{pos}.path_finished?
            request#{pos.next} = request#{pos}.clone
            request#{pos.next}.params << URI.unescape(request#{pos.next}.path.shift)
            #{super(pos.next)}
          end
        ")
      end
    end
  end
end