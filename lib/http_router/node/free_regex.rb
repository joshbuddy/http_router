class HttpRouter
  class Node
    class FreeRegex < Node
      attr_reader :matcher
      def initialize(router, matcher)
        @matcher = matcher
        super(router)
      end

      def to_code(pos)
        indented_code pos, "
        whole_path = \"/\#{r#{pos}.joined_path}\"
        if match = #{matcher.inspect}.match(whole_path) and match[0].size == whole_path.size
          r#{pos.next} = r#{pos}.dup
          r#{pos.next}.extra_env['router.regex_match'] = match
          r#{pos.next}.path = ['']
          " << (//.respond_to?(:names) ?
          "match.names.size.times{|i| r#{pos.next}.params << match[i + 1]} if match.respond_to?(:names) && match.names" : "") << "
          #{super(pos.next)}
        end"
      end

      def usuable?(other)
        other.class == self.class && other.matcher == matcher
      end
    end
  end
end