class HttpRouter
  class Node
    class FreeRegex < Node
      attr_reader :matcher
      def initialize(router, matcher)
        @router, @matcher = router, matcher
      end

      def [](request)
        whole_path = "/#{join_whole_path(request)}"
        if match = @matcher.match(whole_path)
          request = request.clone
          request.extra_env['router.regex_match'] = match
          super
        end
      end
    end
  end
end