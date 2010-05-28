class HttpRouter
  class Route
    attr_reader :dest, :paths
    attr_accessor :trailing_slash_ignore, :partially_match, :default_values

    def initialize(base, path)
      @router = base
      @path = path
      @original_path = path.dup
      @partially_match = extract_partial_match(path)
      @trailing_slash_ignore = extract_trailing_slash(path)
      @variable_store = {}
      @matches_with = {}
      @conditions =  {}
      @default_values = {}
    end

    def significant_variable_names
      unless @significant_variable_names
        @significant_variable_names = @paths.map { |p| p.variable_names }
        @significant_variable_names.flatten!
        @significant_variable_names.uniq!
      end
      @significant_variable_names
    end

    def method_missing(method, *args, &block)
      if RequestNode::RequestMethods.include?(method)
        condition(method => args)
      else
        super
      end
    end

    def name(name)
      @name = name
      router.named_routes[name] = self
    end

    def default(v)
      @default_values.merge!(v)
      self
    end

    def get
      request_method('GET', 'HEAD')
    end
    
    def post
      request_method('POST')
    end
    
    def head
      request_method('HEAD')
    end
    
    def put
      request_method('PUT')
    end
    
    def delete
      request_method('DELETE')
    end
    
    def only_get
      request_method('DELETE')
    end
      
    def condition(conditions)
      guard_compiled
      conditions.each do |k,v|
        @conditions.key?(k) ?
          @conditions[k] << v :
          @conditions[k] = Array(v)
      end
      self
    end
    alias_method :conditions, :condition

    def matching(match)
      guard_compiled
      @matches_with.merge!(match)
      self
    end

    def named
      @name
    end

    def to(dest = nil, &block)
      compile
      @dest = dest || block
      self
    end

    def partial(match = true)
      @partially_match = match
      self
    end
  
    def compiled?
      !@paths.nil?
    end
  
    def compile
      unless @paths
        @paths = compile_paths
        @paths.each_with_index do |p1, i|
          @paths[i+1, @paths.size].each do |p2|
            raise AmbigiousRouteException.new if p1 === p2
          end
        end
        @paths.each do |path|
          path.route = self
          current_node = router.root.add_path(path)
          working_set = current_node.add_request_methods(@conditions)
          working_set.each do |current_node|
            current_node.value = path
          end
        end
      end
      self
    end
  
    def redirect(path, status = 302)
      guard_compiled
      raise(ArgumentError, "Status has to be an integer between 300 and 399") unless (300..399).include?(status)
      to { |env|
        params = env['router.params']
        response = ::Rack::Response.new
        response.redirect(eval(%|"#{path}"|), status)
        response.finish
      }
      self
    end
    
    def static(root)
      guard_compiled
      raise AlreadyCompiledException.new if compiled?
      if File.directory?(root)
        partial.to ::Rack::File.new(root)
      else
        to proc{|env| env['PATH_INFO'] = File.basename(root); ::Rack::File.new(File.dirname(root)).call(env)}
      end
      self
    end

    def trailing_slash_ignore?
      @trailing_slash_ignore
    end

    def partially_match?
      @partially_match
    end

    def url(*args)
      options = args.last.is_a?(Hash) ? args.pop : nil
      options = default_values.merge(options) if default_values && options
      path = if args.empty?
        matching_path(options)
      else
        matching_path(args, options)
      end
      raise UngeneratableRouteException.new unless path
      path.url(args, options)
    end

    private
    
    attr_reader :router

    def matching_path(params, other_hash = nil)
      if @paths.size == 1
        @paths.first
      else
        if params.is_a?(Array)
          significant_keys = other_hash && significant_variable_names & other_hash.keys
          @paths.find { |path| 
            var_count = significant_keys ? params.size + significant_keys.size : params.size
            path.variables.size == var_count
          }
        else
          @paths.reverse_each do |path|
            if params && !params.empty?
              return path if (path.variable_names & params.keys).size == path.variable_names.size
            elsif path.variable_names.empty?
              return path
            end
          end
          nil
        end
      end
    end
    
    def extract_partial_match(path)
      path[-1] == ?* && path.slice!(-1)
    end

    def extract_trailing_slash(path)
      path[-2, 2] == '/?' && path.slice!(-2, 2)
    end

    def extract_extension(path)
      if match = path.match(/^(.*)(\.:([a-zA-Z_]+))$/)
        path.replace(match[1])
        router.variable(match[3].to_sym)
      elsif match = path.match(/^(.*)(\.([a-zA-Z_]+))$/)
        path.replace(match[1])
        match[3]
      end
    end


    def compile_optionals(path)
      start_index = 0
      end_index = 1

      paths = [""]
      chars = path.split('')

      chars.each do |c|
        case c
          when '('
            # over current working set, double paths
            (start_index...end_index).each do |path_index|
              paths << paths[path_index].dup
            end
            start_index = end_index
            end_index = paths.size
          when ')'
            start_index -= end_index - start_index
          else
            (start_index...end_index).each do |path_index|
              paths[path_index] << c
            end
        end
      end
      paths
    end

    def compile_paths
      paths = compile_optionals(@path)
      paths.map do |path|
        original_path = path.dup
        extension = extract_extension(path)
        new_path = router.split(path).map do |part|
          case part[0]
          when ?:
            v_name = part[1, part.size].to_sym
            @variable_store[v_name] ||= router.variable(v_name, @matches_with[v_name])
          when ?*
            v_name = part[1, part.size].to_sym
            @variable_store[v_name] ||= router.glob(v_name, @matches_with[v_name])
          else
            generate_interstitial_parts(part)
          end
        end
        new_path.flatten!
        Path.new(original_path, new_path, extension)
      end
    end

    def generate_interstitial_parts(part)
      part_segments = part.split(/(:[a-zA-Z_]+)/)
      if part_segments.size > 1
        index = 0
        part_segments.map do |seg|
          new_seg = if seg[0] == ?:
            next_index = index + 1
            scan_regex = if next_index == part_segments.size
              /^[^\/]+/
            else
              /^.*?(?=#{Regexp.quote(part_segments[next_index])})/
            end
            v_name = seg[1, seg.size].to_sym
            @variable_store[v_name] ||= router.variable(v_name, scan_regex)
          else
            /^#{Regexp.quote(seg)}/
          end
          index += 1
          new_seg
        end
      else
        part
      end
    end

    def guard_compiled
      raise AlreadyCompiledException.new if compiled?
    end
  end
end
