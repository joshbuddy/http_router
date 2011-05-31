class HttpRouter
  class Node
    class Request < Node
      attr_reader :request_method, :opts

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

      def usuable?(other)
        other.class == self.class && other.opts == opts
      end

      def to_code(pos)
        code = "\nif "
        code << @opts.map do |k,v|
          case v
          when Array then "#{v.inspect}.any?{|vv| vv === request#{pos}.rack_request.send(#{k.inspect})}"
          else            "#{v.inspect} === request#{pos}.rack_request.send(#{k.inspect})"
          end           
        end * ' and '
        code << "\n#{super}\nend\n"
      end
    end
  end
end