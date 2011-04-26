class HttpRouter
  class Node
    class Arbitrary < Node
      def initialize(router, allow_partial, blk, param_names)
        @allow_partial, @blk, @param_names = allow_partial, blk, param_names
        super(router)
      end

      def [](request)
        if request.path.empty? or (request.path.size == 1 and request.path[0] == '') or @allow_partial
          catch(:pass) do
            request = request.clone
            request.continue = proc { |state| super(request) if state }
            params = @param_names.nil? ? {} : Hash[@param_names.zip(request.params)]
            @blk.call(request, params)
          end
        end
      end
    end
  end
end