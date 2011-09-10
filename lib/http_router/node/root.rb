class HttpRouter
  class Node
    class Root < Node
      attr_reader :methods_module, :compiled
      alias_method :compiled?, :compiled
      def initialize(router)
        super(router, nil)
        @counter, @methods_module = 0, Module.new
      end

      def uncompile
        instance_eval "undef :[]; def [](req) raise 'uncompiled root'; end", __FILE__, __LINE__ if compiled?
      end

      def next_counter
        @counter += 1
      end

      def inject_root_ivar(obj)
        name = :"@ivar_#{@counter += 1}"
        root.instance_variable_set(name, obj)
        name
      end

      def depth
        0
      end

      def inspect_label
        "Root (#{@matchers.size} matchers)"
      end

      def compile(routes)
        routes.each {|route| add_route(route)}
        root.extend(root.methods_module)
        instance_eval "def [](request)\n#{to_code}\nnil\nend", __FILE__, __LINE__
        @compiled = true
      end

      private
      def add_route(route)
        paths = if route.path.nil?
          route.match_partially = true
          []
        elsif route.path.is_a?(Regexp)
          [route.path]
        else
          path_for_processing = route.path.dup
          start_index, end_index = 0, 1
          raw_paths, chars = [""], route.path.split('')
          until chars.empty?
          case fc = chars.first[0]
            when ?(
              chars.shift
              (start_index...end_index).each { |path_index| raw_paths << raw_paths[path_index].dup }
              start_index = end_index
              end_index = raw_paths.size
            when ?)
              chars.shift
              start_index -= end_index - start_index
            else
              c = if chars[0][0] == ?\\ && (chars[1][0] == ?( || chars[1][0] == ?)); chars.shift; chars.shift; else; chars.shift; end
              (start_index...end_index).each { |path_index| raw_paths[path_index] << c } 
            end
          end
          raw_paths
        end
        paths.reverse!
        if paths.empty?
          add_non_path_to_tree(route, @router.root, nil, [])
        else
          paths.each do |path|
            case path
            when Regexp
              param_names = path.respond_to?(:names) ? path.names.map(&:to_sym) : []
              Util.add_path_generation(route, route, route.path_for_generation, path) if route.path_for_generation
              route.instance_eval "extend RegexRouteGeneration", __FILE__, __LINE__
              add_non_path_to_tree(route, add_free_match(path), path, param_names)
            else
              param_names = []
              node = self
              path.split(/\//).each do |part|
                next if part == ''
                parts = part.scan(/\\.|[:*][a-z0-9_]+|[^:*\\]+/)
                node = parts.size == 1 ? add_normal_part(route, node, part, param_names) : add_complex_part(route, node, parts, param_names)
              end
              add_non_path_to_tree(route, node, path, param_names)
            end
          end
        end
      end

      def add_normal_part(route, node, part, param_names)
        name = part[1, part.size]
        node = case part[0]
        when ?\\
          node.add_lookup(part[1].chr)
        when ?:
          param_names << name.to_sym
          route.matches_with(name) ? node.add_spanning_match(route.matches_with(name)) : node.add_variable
        when ?*
          param_names << name.to_sym
          route.matches_with(name) ? node.add_glob_regexp(route.matches_with(name)) : node.add_glob
        else
          node.add_lookup(part)
        end
      end

      def add_complex_part(route, node, parts, param_names)
        capturing_indicies, splitting_indicies, captures, spans = [], [], 0, false
        regex = parts.inject('') do |reg, part|
          reg << case part[0]
          when ?\\ then Regexp.quote(part[1].chr)
          when ?:, ?*
            spans = true if part[0] == ?*
            captures += 1
            (part[0] == ?* ? splitting_indicies : capturing_indicies) << captures
            name = part[1, part.size].to_sym
            param_names << name
            if spans
              route.matches_with(name) ? "((?:#{route.matches_with(name)}\\/?)+)" : '(.*?)'
            else
              "(#{(route.matches_with(name) || '[^/]*?')})"
            end
          else
            Regexp.quote(part)
          end
        end
        spans ? node.add_spanning_match(Regexp.new("#{regex}$"), capturing_indicies, splitting_indicies) :
          node.add_match(Regexp.new("#{regex}$"), capturing_indicies, splitting_indicies)
      end

      def add_non_path_to_tree(route, node, path, names)
        node = node.add_host([route.host, route.other_hosts].flatten.compact) if route.host or route.other_hosts
        node = node.add_user_agent(route.user_agent) if route.user_agent
        node = node.add_request_method(route.request_methods) if route.request_methods
        node = node.add_scheme(route.schemes) if route.schemes
        path_obj = node.add_destination(route, path, names)
        path_obj
      end

    end
  end
end