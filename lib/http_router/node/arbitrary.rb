class HttpRouter
  class Node
    class Arbitrary < Node
      def initialize(router, blk, param_names)
        @router, @blk, @param_names = router, blk, param_names
      end

      def [](request)
        request = request.clone
        params = Hash[@param_names.zip(request.params)]
        @blk.call(request.rack_request, params) and super(request)
      end
    end
  end
end