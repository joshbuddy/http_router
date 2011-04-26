class HttpRouter
  class Node
    class FreeRegex < Node
      attr_reader :matcher
      def initialize(router, matcher)
        @matcher = matcher
        super(router)
      end

      def [](request)
        whole_path = "/#{request.joined_path}"
        if match = @matcher.match(whole_path) and match[0].size == whole_path.size
          request = request.clone
          request.extra_env['router.regex_match'] = match
          request.path = ['']
          match.names.size.times{|i| request.params << match[i + 1]} if match.respond_to?(:names) && match.names
          super
        end
      end
    end
  end
end