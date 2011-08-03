class HttpRouter
  class Node
    class Root < Node
      attr_reader :methods_module, :compiled
      alias_method :compiled?, :compiled
      def initialize(router)
        super(router, nil)
        @counter, @methods_module = 0, Module.new
      end

      def [](request)
        compile
        self[request]
      end
      alias_method :compiling_lookup, :[]

      def uncompile
        instance_eval "undef :[]; alias :[] :compiling_lookup", __FILE__, __LINE__ if compiled?
      end

      def next_counter
        @counter += 1
      end

      def inject_root_ivar(obj)
        name = :"@ivar_#{@counter += 1}"
        root.instance_variable_set(name, obj)
        name
      end

      def depth
        0
      end

      def inspect_label
        "Root (#{@matchers.size} matchers)"
      end

      private
      def compile
        root.extend(root.methods_module)
        instance_eval "def [](request)\n#{to_code}\nnil\nend", __FILE__, __LINE__
        @compiled = true
      end
    end
  end
end