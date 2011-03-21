class HttpRouter
  class Node
    class Request < Node
      def self.request_methods
        [:host, :scheme, :request_method, :user_agent]
      end

      attr_reader :request_method

      def initialize(router)
        @router, @linear, @catchall, @lookup = router, [], nil, {}
      end

      def transform_to(meth)
        new_node = Request.new(router)
        new_node.request_method = @request_method
        new_node.instance_var_set(:@linear, @linear.dup)
        new_node.instance_var_set(:@catchall, @catchall)
        new_node.instance_var_set(:@lookup, @lookup.dup)
        @linear.clear
        @lookup.clear
        @catchall = new_node
        @request_method = meth
        new_node
      end

      def request_method=(meth)
        @request_method = meth == :method ? :request_method : meth
        if @destination
          next_node = add_catchall
          next_node.instance_variable_set(:@destination, (next_node.instance_variable_get(:@destination) || []).concat(@destination))
          @destination.clear
        end
        @request_method
      end

      def add_lookup(val)
        @lookup[val] ||= Request.new(@router)
      end

      def add_catchall
        @catchall ||= Request.new(@router)
      end

      def add_linear(matcher)
        next_node = Request.new(@router)
        @linear << [matcher, next_node]
        next_node
      end

      def [](request)
        if @request_method
          val = request.rack_request.send(@request_method.to_sym)
          @linear.each { |(matcher, node)| node[request] if matcher === val }
          @lookup[val][request] if @lookup.key?(val)
          @catchall[request] if @catchall
        else
          super(request)
        end
      end
    end
  end
end