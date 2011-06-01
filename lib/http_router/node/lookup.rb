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
        root_methods = @map.keys.map {|k| "
          define_method(\"lookup_#{object_id} #{k}\") do |request|
            part = request.path.shift
            #{@map[k].map{|n| n.to_code} * "\n"}
            request.path.unshift part
          end"}.join("\n")
        root_methods_module = Module.new
        root_methods_module.module_eval(root_methods)
        router.root.extend root_methods_module
        code = "\nm = :\"lookup_#{object_id} \#{request.path.first}\";send(m, request) if respond_to?(m)\n"
      end
    end
  end
end