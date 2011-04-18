class HttpRouter
  class Node
    class Request < Node
      attr_reader :request_method

      def initialize(router, opts)
        @opts = opts
        Array(@opts[:request_method]).each { |m| router.known_methods << m } if @opts.key?(:request_method)
        super(router)
      end

      def [](request)
        @opts.each{|k,v|
          test = request.rack_request.send(k)
          return unless case v
          when Array then v.any?{|vv| vv === test}
          else            v === test
          end
        }
        super(request)
      end
    end
  end
end