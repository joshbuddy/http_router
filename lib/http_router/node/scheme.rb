class HttpRouter
  class Node
    class Scheme < AbstractRequestNode
      def initialize(router, parent, scheme)
        super(router, parent, scheme, :scheme)
      end
    end
  end
end