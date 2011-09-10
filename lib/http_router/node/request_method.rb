class HttpRouter
  class Node
    class RequestMethod < AbstractRequestNode
      def initialize(router, parent, request_methods)
        super(router, parent, request_methods, :request_method)
      end
    end
  end
end