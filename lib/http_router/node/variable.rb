class HttpRouter
  class Node
    class Variable < Node
      def [](request)
        unless request.path.empty?
          request = request.clone
          request.params << URI.unescape(request.path.shift)
          super(request)
        end
      end

      def usuable?(other)
        other.class == self.class
      end
    end
  end
end