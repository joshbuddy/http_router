class HttpRouter
  class Node
    class Arbitrary < Node
      def initialize(blk, param_names)
        @blk, @param_names = blk, param_names
      end

      def [](request)
        request = request.clone
        params = Hash[@param_names.zip(request.params)]
        @blk.call(request.rack_request, params) and super(request)
      end
    end
  end
end