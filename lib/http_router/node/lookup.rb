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
        lookup_ivar = :"@lookup_#{router.next_counter}"
        inject_root_ivar(lookup_ivar, @map)
        inject_root_methods @map.keys.map {|k| 
          method = :"lookup_#{object_id}_#{k.hash}"
          "define_method(#{method.inspect}) do |request|
            part = request.path.shift
            #{@map[k].map{|n| n.to_code} * "\n"}
            request.path.unshift part
          end"}.join("\n")
        code = "
        send(\"lookup_#{object_id}_\#{request.path.first.hash}\", request) if !request.path_finished? && #{lookup_ivar}.key?(request.path.first)
        "
      end
    end
  end
end