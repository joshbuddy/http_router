class HttpRouter
  class Node
    class Host < AbstractRequestNode
      def initialize(router, parent, hosts)
        super(router, parent, hosts, :host)
      end
    end
  end
end