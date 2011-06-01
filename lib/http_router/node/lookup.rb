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

      def usuable?(other)
        other.class == self.class
      end

      def to_code
        code = "\ncase request.path.first\n"
        @map.keys.each do |k|
          code << "when #{k.inspect}\n
  part#{depth} = request.path.shift
  #{@map[k].map{|n| n.to_code} * "\n"}
  request.path.unshift part#{depth}
  "
        end
        code << "\nend"
      end
    end
  end
end