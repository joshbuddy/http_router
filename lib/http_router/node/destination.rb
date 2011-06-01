class HttpRouter
  class Node
    class Destination < Node
      attr_reader :blk, :allow_partial, :param_names
      
      def initialize(router, parent, blk, allow_partial)
        @blk, @allow_partial = blk, allow_partial
        @node_position = router.register_node(blk)
        super(router, parent)
      end

      def usable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk
      end

      def to_code
        "#{"if request.path_finished?" unless @allow_partial}
          request.passed_with = catch(:pass) do
            router.nodes.at(#{node_position})[request, #{@param_names.nil? || @param_names.empty? ? 'nil' : "Hash[#{@param_names.inspect}.zip(request.params)]"}]
          end
        #{"end" unless @allow_partial}"
      end
    end
  end
end