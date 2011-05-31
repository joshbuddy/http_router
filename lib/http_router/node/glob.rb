class HttpRouter
  class Node
    class Glob < Node
      def [](request)
        request = request.clone
        request.params << []
        remaining_parts = request.path.dup
        until remaining_parts.empty?
          request.params[-1] << URI.unescape(remaining_parts.shift)
          request.path = remaining_parts
          super(request)
        end
      end

      def usuable?(other)
        other.class == self.class
      end
    end
  end
end