class HttpRouter
  class Node
    class Request < Node
      VALID_HTTP_VERBS = %w[HEAD GET DELETE POST PUT OPTIONS PATCH TRACE CONNECT]

      attr_reader :request_method, :opts

      def initialize(router, parent, opts)
        @opts = opts
        Array(@opts[:request_method]).each { |m| router.known_methods << m } if @opts.key?(:request_method)
        super(router, parent)
      end

      def usable?(other)
        other.class == self.class && other.opts == opts
      end

      def to_code
        code = "if "
        code << @opts.map do |k,v|
          v = [v] unless v.is_a?(Array)
          case k
          when :request_method
            v.map!{|vv| vv.to_s.upcase}
            v.all?{|m| VALID_HTTP_VERBS.include?(m)} or raise InvalidRequestValueError, "Invalid value for request_method #{v.inspect}"
          end
          case v.size
          when 1 then to_code_condition(k, v.first)
          else        "(#{v.map{|vv| to_code_condition(k, vv)}.join(' or ')})"
          end           
        end * ' and '
        code << "\n  #{super}\nend"
      end

      private
      def to_code_condition(k, v)
        case v
        when String then "#{v.inspect} == request.rack_request.#{k}"
        else             "#{v.inspect} === request.rack_request.#{k}"
        end
      end
    end
  end
end