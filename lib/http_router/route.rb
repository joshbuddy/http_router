require 'strscan'

class HttpRouter
  class Route
    attr_reader :dest, :paths, :path, :matches_with, :original_path
    attr_accessor :trailing_slash_ignore, :partially_match, :default_values

    def initialize(router, path)
      @router = router
      path[0,0] = '/' unless path[0] == ?/
      @path = path
      @original_path = path.dup
      @partially_match = extract_partial_match(path)
      @trailing_slash_ignore = extract_trailing_slash(path)
      @matches_with = {}
      @arbitrary = []
      @conditions =  {}
      @default_values = {}
    end

    def method_missing(method, *args, &block)
      if RequestNode::RequestMethods.include?(method)
        condition(method => args)
      else
        super
      end
    end

    def to_s
      "#{@original_path} conditions: #{@conditions.inspect} default_values: #{@default_values.inspect} name: #{named.inspect}"
    end

    # Returns the options used to create this route.
    def as_options
      {:matching => @matches_with, :conditions => @conditions, :default_values => @default_values, :name => @name, :partial => @partially_match, :arbitrary => @arbitrary}
    end

    # Creates a deep uncompiled copy of this route.
    def clone(new_router)
      Route.new(new_router, @original_path.dup).with_options(as_options)
    end

    # Uses an option hash to apply conditions to a Route.
    # The following keys are supported.
    # *name -- Maps to #name method.
    # *matching -- Maps to #matching method.
    # *conditions -- Maps to #conditions method.
    # *default_value -- Maps to #default_value method.
    def with_options(options)
      if options
        name(options.delete(:name))                               if options[:name]
        matching(options.delete(:matching))                       if options[:matching]
        condition(options.delete(:conditions))                    if options[:conditions]
        default(options.delete(:default_values))                  if options[:default_values]
        partial(options.delete(:partial))                         if options[:partial]
        Array(options.delete(:arbitrary)).each{|a| arbitrary(&a)} if options[:arbitrary]
        matching(options)
      end
      self
    end

    # Sets the name of the route
    # Returns +self+.
    def name(name)
      @name = name
      router.named_routes[@name] = self if @name && compiled?
      self
    end

    # Sets a default value for the route
    # Returns +self+.
    #
    # Example
    #   router = HttpRouter.new
    #   router.add("/:test").default(:test => 'foo').name(:test).compile
    #   router.url(:test)
    #   # ==> "/foo"
    #   router.url(:test, 'override')
    #   # ==> "/override"
    def default(v)
      @default_values.merge!(v)
      self
    end

    # Causes this route to recognize the GET request method. Returns +self+.
    def get
      request_method('GET')
    end

    # Causes this route to recognize the POST request method. Returns +self+.
    def post
      request_method('POST')
    end

    # Causes this route to recognize the HEAD request method. Returns +self+.
    def head
      request_method('HEAD')
    end

    # Causes this route to recognize the PUT request method. Returns +self+.
    def put
      request_method('PUT')
    end

    # Causes this route to recognize the DELETE request method. Returns +self+.
    def delete
      request_method('DELETE')
    end

    # Sets a request condition for the route
    # Returns +self+.
    #
    # Example
    #   router = HttpRouter.new
    #   router.add("/:test").condition(:host => 'www.example.org').name(:test).compile
    def condition(conditions)
      guard_compiled
      conditions.each do |k,v|
        @conditions.key?(k) ?
          @conditions[k] << v :
          @conditions[k] = Array(v)
        @conditions[k].flatten!
      end
      self
    end
    alias_method :conditions, :condition

    # Sets a regex matcher for a variable
    # Returns +self+.
    #
    # Example
    #   router = HttpRouter.new
    #   router.add("/:test").matching(:test => /\d+/).name(:test).compile
    def matching(match)
      guard_compiled
      match.each do |var_name, matchers|
        matchers = Array(matchers)
        matchers.each do |m|
          @matches_with.key?(var_name) ? raise : @matches_with[var_name] = m
        end
      end
      self
    end

    # Returns the current route's name.
    def named
      @name
    end

    # Sets the destination of the route. Receives either a block, or a proc.
    # Returns +self+.
    #
    # Example
    #   router = HttpRouter.new
    #   router.add("/:test").matching(:test => /\d+/).name(:test).to(proc{ |env| Rack::Response.new("hi there").finish })
    # Or
    #   router.add("/:test").matching(:test => /\d+/).name(:test).to { |env| Rack::Response.new("hi there").finish }
    def to(dest = nil, &block)
      compile
      @dest = dest || block
      if @dest.respond_to?(:url_mount=)
        urlmount = UrlMount.new(@original_path, @default_values)
        urlmount.url_mount = router.url_mount if router.url_mount
        @dest.url_mount = urlmount
      end
      self
    end

    # Sets partial matching on this route. Defaults to +true+. Returns +self+.
    def partial(match = true)
      @partially_match = match
      self
    end

    # Convenient regexp matching on an entire path. Returns +self+
    def match_path(matcher)
      arbitrary{|env, params, dest| match = matcher.match(env.path_info); !match.nil? and match.begin(0) == 0 and match[0].size == env.path_info.size}
    end

    # Adds an arbitrary proc matcher to a Route. Receives either a block, or a proc. The proc will receive a Rack::Request object, a Hash of the params, and the destination for this route. The proc must return true if the Route is matched. Returns +self+.
    def arbitrary(proc = nil, &block)
      guard_compiled
      @arbitrary << (proc || block)
      self
    end

    # Compile state for route. Returns +true+ or +false+.
    def compiled?
      !@paths.nil?
    end

    # Compiles the route and inserts it into the tree. This is called automatically when you add a destination via #to to the route. Until a route
    # is compiled, it will not be recognized.
    def compile
      if @paths.nil?
        router.named_routes[@name] = self if @name
        @paths = compile_paths
        @paths.each_with_index do |p1, i|
          @paths[i+1, @paths.size].each do |p2|
            raise AmbiguousRouteException if p1 === p2
          end
        end
        @paths.each do |path|
          current_node = router.root.add_path(path)
          working_set = current_node.add_request_methods(@conditions)
          working_set.map!{|node| node.add_arbitrary(@arbitrary)}
          working_set.each do |current_node|
            case current_node.value
            when nil
              current_node.value = [path]
            else
              current_node.value << path
            end
          end
          path.variable_names.each{|vn| router.variable_names << vn} unless path.static?
        end
      end
      self
    end

    # Sets the destination of this route to redirect to an arbitrary URL.
    def redirect(path, status = 302)
      raise ArgumentError, "Status has to be an integer between 300 and 399" unless (300..399).include?(status)
      to { |env|
        params = env['router.params']
        response = ::Rack::Response.new
        response.redirect(eval(%|"#{path}"|), status)
        response.finish
      }
      self
    end

    # Sets the destination of this route to serve static files from either a directory or a single file.
    def static(root)
      if File.directory?(root)
        partial.to ::Rack::File.new(root)
      else
        to proc{|env| env['PATH_INFO'] = File.basename(root); ::Rack::File.new(File.dirname(root)).call(env)}
      end
      self
    end

    # The current state of trailing / ignoring on this route. Returns +true+ or +false+.
    def trailing_slash_ignore?
      @trailing_slash_ignore
    end

    # The current state of partial matching on this route. Returns +true+ or +false+.
    def partially_match?
      @partially_match
    end

    # Generates a URL for this route. See HttpRouter#url for how the arguments for this are structured.
    def url(*args)
      result, extra_params = url_with_params(*args)
      router.append_querystring(result, extra_params)
    end

    def url_with_params(*args)
      options = args.last.is_a?(Hash) ? args.pop : nil
      options = options.nil? ? default_values.dup : default_values.merge(options) if default_values
      options.delete_if{ |k,v| v.nil? } if options
      path = if args.empty?
        matching_path(options)
      else
        matching_path(args, options)
      end
      raise UngeneratableRouteException unless path
      result, params = path.url(args, options)
      mount_point = router.url_mount && router.url_mount.url(options)
      mount_point ? [File.join(mount_point, result), params] : [result, params]
    end

    def significant_variable_names
      @significant_variable_names ||= @path.scan(/(^|[^\\])[:\*]([a-zA-Z0-9_]+)/).map{|p| p.last.to_sym}
    end

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

    private

    attr_reader :router

    def extract_partial_match(path)
      path[-1] == ?* && path.slice!(-1)
    end

    def extract_trailing_slash(path)
      path[-2, 2] == '/?' && path.slice!(-2, 2)
    end

    def anonymous_variable(pos)
      "$#{pos}".to_sym
    end

    def compile_paths
      paths = HttpRouter::OptionalCompiler.new(@path).paths
      paths.map do |path|
        splitting_indexes = []
        variable_position = 0
        counter = 0
        original_path = path.dup
        split_path = router.split(path)
        position = 0
        new_path = split_path.map do |part|
          processed_parts = case part
          when /^:([a-zA-Z_0-9]*)$/
            v_name = $1.empty? ? anonymous_variable(counter += 1) : $1.to_sym
            router.variable(v_name, @matches_with[v_name])
          when /^\*([a-zA-Z_0-9]*)$/
            if position != split_path.size - 1
              v_name = $1.empty? ? anonymous_variable(counter += 1) : $1.to_sym
              splitting_indexes << variable_position
              remaining_path_parts = split_path[position + 1, split_path.size]
              look_ahead_variable = remaining_path_parts.find{|p| p[0] == ?: || p[0] == ?*}
              remaining_matcher = split_path[position + 1, look_ahead_variable ? remaining_path_parts.index(look_ahead_variable) : split_path.size].join('/')
              remaining_path_parts.index(look_ahead_variable) if look_ahead_variable
              router.variable(v_name, /^(#{@matches_with[v_name] || '[^\/]*?'}\/)+(?=#{Regexp.quote(remaining_matcher)})/)
            else
              v_name = $1.empty? ? anonymous_variable(counter += 1) : $1.to_sym
              router.glob(v_name, @matches_with[v_name])
            end
          else
            generate_interstitial_parts(part)
          end
          variable_position += Array(processed_parts).select{|part| part.is_a?(Variable)}.size
          position += 1
          processed_parts
        end
        new_path.flatten!
        Path.new(self, original_path, new_path, splitting_indexes.empty? ? nil : splitting_indexes)
      end
    end

    def generate_interstitial_parts(part)
      part_segments = []
      scanner = StringScanner.new(part)
      while !scanner.eos?
        if scanner.scan(/\\[:\*]/)
          part_segments << [:static, ''] if part_segments.last.nil? or part_segments.last.first == :variable
          part_segments.last.last << scanner.matched[-1].chr
        elsif scanner.scan(/\\/)
          # do nothing
        elsif scanner.scan(/:[a-zA_Z0-9_]+/)
          part_segments << [:variable, scanner.matched]
        elsif scanner.scan(/./)
          part_segments << [:static, ''] if part_segments.last.nil? or part_segments.last.first == :variable
          part_segments.last.last << scanner.matched
        end
      end
      priority = 0
      if part_segments.size > 1
        index = 0
        segs = part_segments.map do |(type, seg)|
          new_seg = if type == :variable
            next_index = index + 1
            v_name = seg[1, seg.size].to_sym
            matcher = @matches_with[v_name]
            scan_regex = if next_index == part_segments.size
              matcher || /^[^\/]+/
            else
              /^#{matcher || '[^\/]+?'}(?=#{Regexp.quote(part_segments[next_index].last)})/
            end
            router.variable(v_name, scan_regex)
          else
            priority += seg.size
            Static.new("^#{Regexp.quote(seg)}")
          end
          index += 1
          new_seg
        end
        segs.each {|seg| seg.priority = priority}
        segs
      else
        [part_segments.last.last]
      end
    end

    def guard_compiled
      raise AlreadyCompiledException if compiled?
    end

  end
end
