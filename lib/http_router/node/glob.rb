class HttpRouter
  class Node
    class Glob < Node
      def usuable?(other)
        other.class == self.class
      end

      def to_code(pos)
        "
request#{pos.next} = request#{pos}.clone
request#{pos.next}.params << []
remaining_parts = request#{pos.next}.path.dup
until remaining_parts.empty?
  request#{pos.next}.params[-1] << URI.unescape(remaining_parts.shift)
  request#{pos.next}.path = remaining_parts
  #{super(pos.next)}
end
        "
      end

    end
  end
end