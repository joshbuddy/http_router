class HttpRouter
  class Node
    class GlobRegex < Glob
      attr_reader :matcher
      def initialize(router, parent, matcher)
        @matcher = matcher
        super router, parent
      end

      def usable?(other)
        other.class == self.class && other.matcher == matcher
      end

      def to_code
        id = root.next_counter
        "request.params << (globbed_params#{id} = [])
          remaining_parts = request.path.dup
          while !remaining_parts.empty? and match = remaining_parts.first.match(#{@matcher.inspect}) and match[0] == remaining_parts.first
            globbed_params#{id} << remaining_parts.shift
            request.path = remaining_parts
            #{node_to_code}
          end
          request.path[0,0] = request.params.pop"
      end
    end
  end
end