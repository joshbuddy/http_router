class HttpRouter
  class Node
    class Request < Node
      VALID_HTTP_VERBS = %w[HEAD GET DELETE POST PUT OPTIONS PATCH TRACE CONNECT]

      attr_reader :request_method, :opts

      def initialize(router, parent, opts)
        opts.each do |k, v|
          v = [v] unless v.is_a?(Array)
          case k
          when :request_method
            v.map!{|val| val.to_s.upcase}
            v.all?{|m| VALID_HTTP_VERBS.include?(m)} or raise InvalidRequestValueError, "Invalid value for request_method #{v.inspect}"
            v.each{|val| router.known_methods << val}
          end
          opts[k] = v
        end
        @opts = opts
        @opts[:request_method].each { |m| router.known_methods << m } if @opts.key?(:request_method)
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
          else        "(#{v.map{|vv| to_code_condition(k, vv)}.join(' or ')})"
          end           
        end * ' and '
        code << "\n  #{super}\nend"
      end

      def inspect_label
        "#{self.class.name.split("::").last} #{opts.inspect} (#{@matchers.size} matchers)"
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