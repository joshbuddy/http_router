class HttpRouter
  class Node
    class Arbitrary < Node
      attr_reader :allow_partial, :blk, :param_names

      def initialize(router, parent, sallow_partial, blk, param_names)
        @allow_partial, @blk, @param_names = allow_partial, blk, param_names
        super(router, parent)
      end

      def usable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk && other.param_names == param_names
      end

      def to_code
        b, method_name = @blk, :"blk_#{root.next_counter}"
        inject_root_methods { define_method(method_name) { b } }
        "#{"if request.path_finished?" unless @allow_partial}
          request.continue = proc { |state|
            if state
              #{super}
            end
          }
          #{method_name}[request, #{@param_names.nil? || @param_names.empty? ? '{}' : "Hash[#{@param_names.inspect}.zip(request.params)]"}]
          request.continue = nil
        #{"end" unless @allow_partial}"
      end
    end
  end
end