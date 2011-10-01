class HttpRouter
  class Node
    class RequestMethod < AbstractRequestNode
      def initialize(router, parent, request_methods)
        super(router, parent, request_methods, :request_method)
      end

      def to_code
        "if #{@tests.map { |test| "#{test.inspect} === request.rack_request.#{request_method}" } * ' or '}
          #{super}
        end
        request.acceptable_methods.merge(#{@tests.inspect})"
      end
    end
  end
end