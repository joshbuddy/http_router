class HttpRouter
  class Node
    class Arbitrary < Node
      attr_reader :allow_partial, :blk, :param_names

      def initialize(router, allow_partial, blk, param_names)
        @allow_partial, @blk, @param_names = allow_partial, blk, param_names
        @node_position = router.register_node(blk)
        super(router)
      end

      def usuable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk && other.param_names == param_names
      end

      def to_code(pos)
        indented_code pos, "
        #{"if r#{pos}.path_finished?" unless @allow_partial}
          r#{pos.next} = r#{pos}.dup
          r#{pos.next}.continue = proc { |state|
            if state
              #{super(pos.next)}
            end
          }
          router.nodes.at(#{node_position})[r#{pos.next}, #{@param_names.nil? || @param_names.empty? ? '{}' : "Hash[#{@param_names.inspect}.zip(r#{pos.next}.params)]"}]
        #{"end" unless @allow_partial}"
      end
    end
  end
end