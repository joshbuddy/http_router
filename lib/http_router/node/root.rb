class HttpRouter
  class Node
    class Root < Node
      def initialize(router)
        super(router, nil)
      end

      def [](request)
        compile
        self[request]
      end

      def compile
        root.extend(root.methods_module)
        instance_eval "def [](request)\n#{to_code}\nnil\nend", __FILE__, __LINE__
      end

      def methods_module
        @module ||= Module.new
      end
    end
  end
end