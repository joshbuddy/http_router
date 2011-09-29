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

      def inspect_matchers_body
        @map.map { |key, values|
          ins = "#{' ' * depth}when #{key.inspect}:\n"
          ins << values.map{|v| v.inspect}.join("\n") }.join("\n")
      end

      def inspect_label
        "#{self.class.name}"
      end

      def to_code
        part_name = "part#{root.next_counter}"
        "unless request.path_finished?
          #{part_name} = request.path.shift
          case #{part_name}
            #{@map.map{|k, v| "when #{k.inspect}; #{v.map(&:to_code) * "\n"};"} * "\n"}
          end
          request.path.unshift #{part_name}
        end"
      end
    end
  end
end