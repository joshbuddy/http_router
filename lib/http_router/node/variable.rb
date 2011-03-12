class HttpRouter
  class Node
    class Variable < Node
      def [](request)
        request = request.clone
        request.params << unescape(request.path.shift)
        super(request)
      end
    end
  end
end