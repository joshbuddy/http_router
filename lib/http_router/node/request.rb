class HttpRouter
  class Node
    class Request < Node
      attr_reader :request_method, :opts

      def initialize(router, parent, opts)
        @opts = opts
        Array(@opts[:request_method]).each { |m| router.known_methods << m } if @opts.key?(:request_method)
        super(router, parent)
      end

      def usuable?(other)
        other.class == self.class && other.opts == opts
      end

      def to_code
        code = "if "
        code << @opts.map do |k,v|
          case v
          when Array then "(#{v.map{|vv| "#{vv.inspect} === request.rack_request.#{k}"}.join(' or ')})"
          else            "#{v.inspect} === request.rack_request.#{k.inspect}"
          end           
        end * ' and '
        code << "\n  #{super}\nend"
      end
    end
  end
end