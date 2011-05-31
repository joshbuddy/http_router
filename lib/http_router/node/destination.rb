class HttpRouter
  class Node
    class Destination < Node
      attr_reader :blk, :allow_partial, :param_names
      
      def initialize(router, blk, allow_partial)
        @blk, @allow_partial = blk, allow_partial
        @node_position = router.register_node(self)
        super(router)
      end

      def usuable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk
      end

      def to_code(pos)
        "
n = router[#{node_position}]
#{"if request#{pos}.path.empty? or (request#{pos}.path.size == 1 and request#{pos}.path.at(0) == '')" unless @allow_partial}
  request#{pos}.passed_with = catch(:pass) do
    n.blk[request#{pos}, #{@param_names.nil? || @param_names.empty? ? 'nil' : "Hash[#{@param_names.inspect}.zip(request#{pos.next}.params)]"}]
  end
#{"end" unless @allow_partial}
        "
      end
    end
  end
end