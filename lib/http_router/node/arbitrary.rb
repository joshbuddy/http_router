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
        "
n = router[#{node_position}]
if request#{pos}.path.empty? or (request#{pos}.path.size == 1 and request#{pos}.path.at(0) == '') or #{@allow_partial.inspect}
  request#{pos.next} = request#{pos}.clone
  request#{pos.next}.continue = proc { |state|
    if state
      #{super(pos.next)}
    end
  }
  params = #{@param_names.nil? || @param_names.empty? ? '{}' : "Hash[#{@param_names.inspect}.zip(request#{pos.next}.params)]"}
  n.blk.call(request#{pos.next}, params)
end
        "
      end
    end
  end
end