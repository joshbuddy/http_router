class HttpRouter
  class Node
    class Request < Node
      attr_reader :request_method, :opts

      def initialize(router, opts)
        @opts = opts
        Array(@opts[:request_method]).each { |m| router.known_methods << m } if @opts.key?(:request_method)
        super(router)
      end

      def usuable?(other)
        other.class == self.class && other.opts == opts
      end

      def to_code(pos)
        code = "if "
        code << @opts.map do |k,v|
          case v
          when Array then "#{v.inspect}.any?{|vv| vv === r#{pos}.rack_request.#{k}}"
          else            "#{v.inspect} === r#{pos}.rack_request.#{k.inspect}"
          end           
        end * ' and '
        code << "\n  #{super}\nend"
        indented_code pos, code
      end
    end
  end
end