class HttpRouter
  class Node
    class Regex < Node
      alias_method :node_to_code, :to_code
      attr_reader :matcher, :splitting_indicies, :capturing_indicies, :ordered_indicies

      def initialize(router, parent, matcher, capturing_indicies, splitting_indicies = nil)
        @matcher, @capturing_indicies, @splitting_indicies = matcher, capturing_indicies, splitting_indicies
        @ordered_indicies = []
        @ordered_indicies.concat(capturing_indicies.map{|i| [i, :capture]}) if capturing_indicies
        @ordered_indicies.concat(splitting_indicies.map{|i| [i, :split]}) if splitting_indicies
        @ordered_indicies.sort!
        super(router, parent)
      end

      def usable?(other)
        other.class == self.class && other.matcher == matcher && other.splitting_indicies == splitting_indicies && other.capturing_indicies == capturing_indicies
      end

      def to_code
        params_size = @splitting_indicies.size + @capturing_indicies.size
        "if match = #{@matcher.inspect}.match(request.path.first) and match.begin(0).zero?
          part = request.path.shift\n" << param_capturing_code <<
          "#{super}
          request.path.unshift part
          #{params_size == 1 ? "request.params.pop" : "request.params.slice!(#{-params_size}, #{params_size})"}
        end"
      end

      def param_capturing_code
        @ordered_indicies.map{|(i, type)|
          case type
          when :capture then "request.params << match[#{i}]\n"
          when :split   then "request.params << match[#{i}].split(/\\//)\n"
          end
        }.join("")
      end
    end
  end
end