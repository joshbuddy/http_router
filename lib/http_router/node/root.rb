class HttpRouter
  class Node
    class Root < Node
      attr_reader :methods_module
      def initialize(router)
        super(router, nil)
        @methods_module = Module.new
      end

      def [](request)
        compile
        self[request]
      end

      private
      def compile
        root.extend(root.methods_module)
        instance_eval "def [](request)\n#{to_code}\nnil\nend", __FILE__, __LINE__
      end
    end
  end
end