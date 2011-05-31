class HttpRouter
  class Node
    class Lookup < Node
      def initialize(router)
        @map = {}
        super(router)
      end

      def add(part)
        Node.new(@router, @map[part] ||= [])
      end

      def usuable?(other)
        other.class == self.class
      end

      def to_code(pos)
        code = "
          case request#{pos}.path.first\n"
        @map.keys.each do |k|
          code << "when #{k.inspect}\n
            request#{pos.next} = request#{pos}.clone
            request#{pos.next}.path.shift
            #{@map[k].map{|n| n.to_code(pos.next)} * "\n"}"
        end
        code << "\nend"
        indented_code pos, code
      end
    end
  end
end