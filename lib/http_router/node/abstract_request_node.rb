class HttpRouter
  class Node
    class AbstractRequestNode < Node
      attr_reader :request_method, :tests

      def initialize(route, parent, tests, request_method)
        @request_method = request_method
        @tests = case tests
        when Array then tests
        when Set   then tests.to_a
        else            [tests]
        end
        super(route, parent)
      end

      def usable?(other)
        other.class == self.class && other.tests == tests && other.request_method == request_method
      end

      def to_code
        "if #{@tests.map { |test| "#{test.inspect} === request.rack_request.#{request_method}" } * ' or '}
          #{super}
        end"
      end

      def inspect_label
        "#{self.class.name.split("::").last} #{tests.inspect} (#{@matchers.size} matchers)"
      end
     end
  end
end