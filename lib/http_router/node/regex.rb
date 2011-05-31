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
        "
if match = #{@matcher.inspect}.match(request#{pos}.path.first) and match.begin(0).zero?
  request#{pos.next} = request#{pos}.clone
  request#{pos.next}.path.shift
  #{"#{@splitting_indicies.inspect}.each { |idx| request#{pos.next}.params << URI.unescape(match[idx]).split(/\\\//) }" if @splitting_indicies}
  #{@capturing_indicies.inspect}.each { |idx| request#{pos.next}.params << URI.unescape(match[idx]) }
  #{super(pos.next)}
end
        "
      end
    end
  end
end