class HttpRouter
  class Node
    class Lookup < Node
      def initialize(router)
        @map = {}
        super(router)
      end

      def [](request)
        if @map[request.path.first]
          request = request.clone
          @map[request.path.shift].each{|m| m[request]}
        end
      end

      def add(part)
        Node.new(@router, @map[part] ||= [])
      end
    end
  end
end