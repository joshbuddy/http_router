class HttpRouter
  class Node
    class Arbitrary < Node
      alias_method :node_lookup, :[]

      def initialize(router, allow_partial, blk, param_names)
        @allow_partial, @blk, @param_names = allow_partial, blk, param_names
        super(router)
      end

      def [](request)
        if request.path.empty? or (request.path.size == 1 and request.path[0] == '') or @allow_partial
          catch(:pass) do
            request = request.clone
            request.continue = proc { |state| node_lookup(request) if state }
            params = @param_names.nil? ? {} : Hash[@param_names.zip(request.params)]
            @blk.call(request, params)
          end
        end
      end
    end
  end
end