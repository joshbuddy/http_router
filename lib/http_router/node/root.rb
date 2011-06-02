class HttpRouter
  class Node
    class Root < Node
      def initialize(router)
        super(router, nil)
      end

      def compile
        root.extend(root.methods_module)
        instance_eval "def [](request)\n#{to_code}\nnil\nend", __FILE__, __LINE__
      end

      def methods_module
        @module ||= Module.new
      end

      def method_missing(m, *args, &blk)
        if m.to_s == '[]'
          compile
          send(:[], *args)
        else
          super
        end
      end
    end
  end
end