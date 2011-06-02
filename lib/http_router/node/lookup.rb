class HttpRouter
  class Node
    class Lookup < Node
      def initialize(router, parent)
        @map = {}
        super(router, parent)
      end

      def add(part)
        Node.new(@router, self, @map[part] ||= [])
      end

      def usable?(other)
        other.class == self.class
      end

      def to_code
        inject_root_methods @map.keys.map {|k| 
          method = :"lookup_#{object_id}_#{k.hash}"
          "define_method(#{method.inspect}) do |request|
            part = request.path.shift
            #{@map[k].map{|n| n.to_code} * "\n"}
            request.path.unshift part
          end"}.join("\n")
        code = "
        unless request.path_finished?
          m = \"lookup_#{object_id}_\#{request.path.first.hash}\"
          send(m, request) if respond_to?(m)
        end
        "
      end
    end
  end
end