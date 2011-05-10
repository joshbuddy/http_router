class HttpRouter
  class Node
    class Regex < Node
      alias_method :node_lookup, :[]
      attr_reader :matcher, :splitting_indicies, :capturing_indicies

      def initialize(router, matcher, capturing_indicies, splitting_indicies = nil)
        @matcher, @capturing_indicies, @splitting_indicies = matcher, capturing_indicies, splitting_indicies
        super(router)
      end

      def [](request)
        if match = @matcher.match(request.path.first) and match.begin(0).zero?
          request = request.clone
          request.path.shift
          add_params(request, match)
          super(request)
        end
      end

      def add_params(request, match)
        @splitting_indicies.each { |idx| request.params << unescape(match[idx]).split(/\//) } if @splitting_indicies
        @capturing_indicies.each { |idx| request.params << unescape(match[idx]) }
      end

      def usuable?(other)
        other.class == self.class && other.matcher == matcher && other.splitting_indicies == splitting_indicies && other.capturing_indicies == capturing_indicies
      end
    end
  end
end