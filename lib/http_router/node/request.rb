class HttpRouter
  class Node
    class Request < Node
      def self.request_methods
        [:host, :request_method, :scheme, :user_agent]
      end

      def initialize(router)
        @router, @linear, @catchall, @lookup = router, [], nil, {}
      end

      def request_method=(meth)
        @request_method = meth == :method ? :request_method : meth
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
        matched = false
        if @request_method
          val = request.rack_request.send(@request_method.to_sym)
          @linear.each { |(matcher, node)| node[request] if matcher === val }
          @lookup[val][request] if @lookup.key?(val)
          @catchall[request] if @catchall
          matched = @lookup.key?(val) || !@catchall.nil?
        else
          super(request)
        end
      end
    end
  end
end