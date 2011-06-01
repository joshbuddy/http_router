class HttpRouter
  class Node
    class Glob < Node
      def usuable?(other)
        other.class == self.class
      end

      def to_code(pos)
        indented_code pos, "
          r#{pos.next} = r#{pos}.dup
          r#{pos.next}.params << []
          remaining_parts = r#{pos.next}.path.dup
          until remaining_parts.empty?
            r#{pos.next}.params[-1] << URI.unescape(remaining_parts.shift)
            r#{pos.next}.path = remaining_parts
            #{super(pos.next)}
          end"
      end
    end
  end
end