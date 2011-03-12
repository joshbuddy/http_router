class HttpRouter
  class Node
    class Regex < Node
      alias_method :node_lookup, :[]

      attr_reader :matcher

      def initialize(router, matcher, capturing_indicies, priority = 0)
        @router, @matcher, @capturing_indicies, @priority = router, matcher, capturing_indicies, priority
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
        @capturing_indicies.each { |idx| request.params << unescape(match[idx]) }
      end
    end
  end
end