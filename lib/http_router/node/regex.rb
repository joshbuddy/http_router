class HttpRouter
  class Node
    class Regex < Node
      alias_method :node_to_code, :to_code
      attr_reader :matcher, :splitting_indicies, :capturing_indicies

      def initialize(router, parent, matcher, capturing_indicies, splitting_indicies = nil)
        @matcher, @capturing_indicies, @splitting_indicies = matcher, capturing_indicies, splitting_indicies
        super(router, parent)
      end

      def usuable?(other)
        other.class == self.class && other.matcher == matcher && other.splitting_indicies == splitting_indicies && other.capturing_indicies == capturing_indicies
      end

      def to_code
        params_size = @splitting_indicies.size + @capturing_indicies.size
        "if match = #{@matcher.inspect}.match(request.path.first) and match.begin(0).zero?
          part = request.path.shift\n" <<
          @splitting_indicies.map { |s| "request.params << URI.unescape(match[#{s}]).split(/\\//)\n" }.join <<
          @capturing_indicies.map { |c| "request.params << URI.unescape(match[#{c}])\n" }.join << "
          #{super}
          request.path.unshift part
          #{params_size == 1 ? "request.params.pop" : "request.params.slice!(#{-params_size}, #{params_size})"}
        end"
      end
    end
  end
end