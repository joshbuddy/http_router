class HttpRouter
  class Node
    class Variable < Node
      def usuable?(other)
        other.class == self.class
      end

      def to_code(pos)
        indented_code(pos, "
          unless r#{pos}.path_finished?
            r#{pos.next} = r#{pos}.clone
            r#{pos.next}.params << URI.unescape(r#{pos.next}.path.shift)
            #{super(pos.next)}
          end")
      end
    end
  end
end