class HttpRouter
  class Node
    class Arbitrary < Node
      attr_reader :allow_partial, :blk, :param_names

      def initialize(router, allow_partial, blk, param_names)
        @allow_partial, @blk, @param_names = allow_partial, blk, param_names
        @node_position = router.register_node(self)
        super(router)
      end

      def usuable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk && other.param_names == param_names
      end

      def to_code(pos)
        indented_code pos, "#{"if request#{pos}.path_finished?" unless @allow_partial}
          request#{pos.next} = request#{pos}.clone
          request#{pos.next}.continue = proc { |state|
            if state
              #{super(pos.next)}
            end
          }
          params = #{@param_names.nil? || @param_names.empty? ? '{}' : "Hash[#{@param_names.inspect}.zip(request#{pos.next}.params)]"}
          router.nodes.at(#{node_position}).blk[request#{pos.next}, params]
        #{"end" unless @allow_partial}"
      end
    end
  end
end