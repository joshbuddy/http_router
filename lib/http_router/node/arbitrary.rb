class HttpRouter
  class Node
    class Arbitrary < Node
      attr_reader :allow_partial, :blk, :param_names

      def initialize(router, parent, sallow_partial, blk, param_names)
        @allow_partial, @blk, @param_names = allow_partial, blk, param_names
        @node_position = router.register_node(blk)
        super(router, parent)
      end

      def usuable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk && other.param_names == param_names
      end

      def to_code
        "#{"if request.path_finished?" unless @allow_partial}
          request.continue = proc { |state|
            if state
              #{super}
            end
          }
          router.nodes.at(#{node_position})[request, #{@param_names.nil? || @param_names.empty? ? '{}' : "Hash[#{@param_names.inspect}.zip(request.params)]"}]
          request.continue = nil
        #{"end" unless @allow_partial}"
      end
    end
  end
end