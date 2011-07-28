class HttpRouter
  class Node
    class FreeRegex < Node
      attr_reader :matcher
      def initialize(router, parent, matcher)
        @matcher = matcher
        super(router, parent)
      end

      def to_code
        id = root.next_counter
        "whole_path#{id} = \"/\#{request.joined_path}\"
        if match = #{matcher.inspect}.match(whole_path#{id}) and match[0].size == whole_path#{id}.size
          request.extra_env['router.regex_match'] = match
          old_path = request.path
          request.path = ['']
          " << (use_named_captures? ?
          "match.names.size.times{|i| request.params << match[i + 1]} if match.respond_to?(:names) && match.names" : "") << "
          #{super}
          request.path = old_path
          request.extra_env.delete('router.regex_match')
          " << (use_named_captures? ?
          "params.slice!(-match.names.size, match.names.size)" : ""
          ) << "
        end"
      end

      def usable?(other)
        other.class == self.class && other.matcher == matcher
      end
    end
  end
end