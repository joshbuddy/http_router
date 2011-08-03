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
        lookup_ivar = inject_root_ivar(@map)
        method_prefix = "lookup_#{root.next_counter} "
        inject_root_methods @map.keys.map {|k| 
          method = :"#{method_prefix}#{k}"
          "define_method(#{method.inspect}) do |request|
            part = request.path.shift
            #{@map[k].map{|n| n.to_code} * "\n"}
            request.path.unshift part
          end"}.join("\n")
        "send(\"#{method_prefix}\#{request.path.first}\", request) if !request.path_finished? && #{lookup_ivar}.key?(request.path.first)"
      end
    end
  end
end