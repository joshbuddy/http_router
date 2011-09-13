class HttpRouter
  class Node
    class Scheme < AbstractRequestNode
      def initialize(router, parent, schemes)
        super(router, parent, schemes, :scheme)
      end
    end
  end
end