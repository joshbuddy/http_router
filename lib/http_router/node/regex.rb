class HttpRouter
  class Node
    class Regex < Node
      alias_method :node_to_code, :to_code
      attr_reader :matcher, :splitting_indicies, :capturing_indicies

      def initialize(router, matcher, capturing_indicies, splitting_indicies = nil)
        @matcher, @capturing_indicies, @splitting_indicies = matcher, capturing_indicies, splitting_indicies
        super(router)
      end

      def add_params(request, match)
        @splitting_indicies.each { |idx| request.params << URI.unescape(match[idx]).split(/\//) } if @splitting_indicies
        @capturing_indicies.each { |idx| request.params << URI.unescape(match[idx]) }
      end

      def usuable?(other)
        other.class == self.class && other.matcher == matcher && other.splitting_indicies == splitting_indicies && other.capturing_indicies == capturing_indicies
      end

      def to_code(pos)
          indented_code pos, "
          if match = #{@matcher.inspect}.match(r#{pos}.path.first) and match.begin(0).zero?
            r#{pos.next} = r#{pos}.dup
            r#{pos.next}.path.shift\n" <<
            @splitting_indicies.map { |s| "r#{pos.next}.params << URI.unescape(match[#{s}]).split(/\\//)\n" }.join <<
            @capturing_indicies.map { |c| "r#{pos.next}.params << URI.unescape(match[#{c}])\n" }.join << "
            #{super(pos.next)}
          end"
      end
    end
  end
end