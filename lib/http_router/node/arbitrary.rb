class HttpRouter
  class Node
    class Arbitrary < Node
      def initialize(router, blk, param_names)
        @router, @blk, @param_names = router, blk, param_names
      end

      def [](request)
        request = request.clone
        request.continue = proc { |state| destination(request) if state }
        params = @param_names.nil? ? {} : Hash[@param_names.zip(request.params)]
        @blk.call(request, params)
      end
    end
  end
end