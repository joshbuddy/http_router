class HttpRouter
  class Node
    class Request < Node
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
          case v.size
          when 1 then to_code_condition(k, v.first)
          else        "(#{v.map{|k, vv| to_code_condition(k, vv)}.join(' or ')})"
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