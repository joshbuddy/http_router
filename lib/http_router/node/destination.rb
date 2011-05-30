class HttpRouter
  class Node
    class Destination < Node
      def initialize(router, blk, allow_partial)
        @blk, @allow_partial = blk, allow_partial
        super(router)
      end

      def [](request)
        if request.path.empty? or (request.path.size == 1 and request.path[0] == '') or @allow_partial
          request.passed_with = catch(:pass) do
            request = request.clone
            request.continue = proc { |state| destination(request) if state }
            params = @param_names.nil? ? {} : Hash[@param_names.zip(request.params)]
            @blk.call(request, params)
          end
        end
      end

      def usuable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk
      end
    end
  end
end