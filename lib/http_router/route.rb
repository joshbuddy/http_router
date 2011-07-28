class HttpRouter
  class Route
    attr_reader :default_values, :router, :path, :conditions, :original_path, :match_partially, :dest, :regex, :named, :matches_with
    alias_method :match_partially?, :match_partially
    alias_method :regex?, :regex

    def initialize(router, path, opts = {})
      @router, @original_path, @opts = router, path, opts
      if @original_path
        @match_partially = true and path.slice!(-1) if @original_path[/[^\\]\*$/]
        @original_path[0, 0] = '/'                  if @original_path[0] != ?/
      else
        @match_partially = true
      end
      process_opts
    end

    def process_opts
      @default_values = @opts[:__default_values__] || @opts[:default_values] || {}
      @arbitrary = @opts[:__arbitrary__] || @opts[:arbitrary]
      @matches_with = significant_variable_names.include?(:matching) ? @opts : @opts[:__matching__] || @opts[:matching] || {}
      significant_variable_names.each do |name|
        @matches_with[name] = @opts[name] if @opts.key?(name) && !@matches_with.key?(name)
      end
      @conditions = @opts[:__conditions__] || @opts[:conditions] || {}
      @match_partially = @opts[:__partial__] if @match_partially.nil? && !@opts[:__partial__].nil?
      @match_partially = @opts[:partial] if @match_partially.nil? && !@opts[:partial].nil?
      name(@opts[:__name__] || @opts[:name]) if @opts.key?(:__name__) || @opts.key?(:name)
      @needed_keys = significant_variable_names - @default_values.keys
    end

    def as_options
      {:__matching__ => @matches_with, :__conditions__ => @conditions, :__default_values__ => @default_values, :__name__ => @named, :__partial__ => @partially_match, :__arbitrary__ => @arbitrary}
    end

    def compiled?
      !@paths.nil?
    end

    def partial(match_partially = true)
      @match_partially = match_partially
      self
    end

    def to(dest = nil, &dest2)
      @dest = dest || dest2
      add_path_to_tree
      self
    end

    def name(n)
      @named = n
      @router.named_routes[n] << self
      @router.named_routes[n].sort!{|r1, r2| r2.significant_variable_names.size <=> r1.significant_variable_names.size }
      self
    end

    def request_method(*method)
      add_to_contitions(:request_method, method)
    end

    def host(*host)
      add_to_contitions(:host, host)
    end

    def scheme(*scheme)
      add_to_contitions(:scheme, scheme)
    end

    def user_agent(*user_agent)
      add_to_contitions(:user_agent, user_agent)
    end

    def add_to_contitions(name, *vals)
      ((@conditions ||= {})[name] ||= []).concat(vals.flatten)
      self
    end

    def matching(matchers)
      @matches_with.merge!(matchers.is_a?(Array) ? Hash[*matchers] : matchers)
      self
    end

    def default(defaults)
      (@default_values ||= {}).merge!(defaults)
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
        to {|env| env['PATH_INFO'] = File.basename(root); ::Rack::File.new(File.dirname(root)).call(env) }
      end
      self
    end

    def post;    request_method('POST');            end
    def get;     request_method('GET');             end
    def put;     request_method('PUT');             end
    def delete;  request_method('DELETE');          end
    def head;    request_method('HEAD');            end
    def options; request_method('OPTIONS');         end
    def patch;   request_method('PATCH');           end
    def trace;   request_method('TRACE');           end
    def conenct; request_method('CONNECT');         end

    def arbitrary(blk = nil, &blk2)
      arbitrary_with_continue { |req, params|
        req.continue[(blk || blk2)[req, params]]
      }
    end

    def arbitrary_with_continue(blk = nil, &blk2)
      (@arbitrary ||= []) << (blk || blk2)
      self
    end

    def url(*args)
      result, extra_params = url_with_params(*args)
      append_querystring(result, extra_params)
    end

    def clone(new_router)
      Route.new(new_router, @original_path.dup, as_options)
    end

    def url_with_params(*a)
      url_args_processing(a) do |args, options|
        path = args.empty? ? matching_path(options) : matching_path(args, options)
        raise InvalidRouteException unless path
        path.url(args, options)
      end
    end

    def url_args_processing(args)
      options = args.last.is_a?(Hash) ? args.pop : nil
      options = options.nil? ? default_values.dup : default_values.merge(options) if default_values
      options.delete_if{ |k,v| v.nil? } if options
      result, params = yield args, options
      mount_point = router.url_mount && router.url_mount.url(options)
      mount_point ? [File.join(mount_point, result), params] : [result, params]
    end

    def significant_variable_names
      @significant_variable_names ||= @original_path.nil? ? [] : @original_path.scan(/(^|[^\\])[:\*]([a-zA-Z0-9_]+)/).map{|p| p.last.to_sym}
    end

    def matching_path(params, other_hash = nil)
      return @paths.first if @paths.size == 1
      case params
      when Array
        significant_keys = other_hash && significant_variable_names & other_hash.keys
        @paths.find { |path| path.param_names.size == (significant_keys ? params.size + significant_keys.size : params.size) }
      when Hash
        @paths.find { |path| (params && !params.empty? && (path.param_names & params.keys).size == path.param_names.size) || path.param_names.empty? }
      end
    end

    def to_s
      "#<HttpRouter:Route #{object_id} @original_path=#{@original_path.inspect} @conditions=#{@conditions.inspect} @arbitrary=#{@arbitrary.inspect}>"
    end

    private
    def raw_paths
      return [] if @original_path.nil?
      @raw_paths ||= begin
        start_index, end_index = 0, 1
        @raw_paths, chars = [""], @original_path.split('')
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
        @raw_paths.reverse!
      end
    end

    def add_normal_part(node, part, param_names)
      name = part[1, part.size]
      node = case part[0]
      when ?\\
        node.add_lookup(part[1].chr)
      when ?:
        param_names << name.to_sym
        @matches_with[name.to_sym] ? node.add_spanning_match(@matches_with[name.to_sym]) : node.add_variable
      when ?*
        param_names << name.to_sym
        @matches_with[name.to_sym] ? node.add_glob_regexp(@matches_with[name.to_sym]) : node.add_glob
      else
        node.add_lookup(part)
      end
    end

    def add_complex_part(node, parts, param_names)
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
            @matches_with[name] ? "((?:#{@matches_with[name]}\\/?)+)" : '(.*?)'
          else
            "(#{(@matches_with[name] || '[^/]*?')})"
          end
        else
          Regexp.quote(part)
        end
      end
      spans ? node.add_spanning_match(Regexp.new("#{regex}$"), capturing_indicies, splitting_indicies) :
        node.add_match(Regexp.new("#{regex}$"), capturing_indicies, splitting_indicies)
    end

    def add_path_to_tree
      raise DoubleCompileError if compiled?
      @paths ||= begin
        if raw_paths.empty?
          add_non_path_to_tree(@router.root, nil, [])
        else
          raw_paths.map do |path|
            param_names = []
            node = @router.root
            path.split(/\//).each do |part|
              next if part == ''
              parts = part.scan(/\\.|[:*][a-z0-9_]+|[^:*\\]+/)
              node = parts.size == 1 ? add_normal_part(node, part, param_names) : add_complex_part(node, parts, param_names)
            end
            add_non_path_to_tree(node, path, param_names)
          end
        end
      end
    end

    def add_non_path_to_tree(node, path, names)
      node = node.add_request(@conditions) unless @conditions.empty?
      @arbitrary.each{|a| node = node.add_arbitrary(a, match_partially?, names)} if @arbitrary
      path_obj = node.add_destination(self, path, names)
      if dest.respond_to?(:url_mount=)
        urlmount = UrlMount.new(@original_path, @default_values)
        urlmount.url_mount = router.url_mount if router.url_mount
        dest.url_mount = urlmount
      end
      path_obj
    end

    def append_querystring_value(uri, key, value)
      case value
      when Array then value.each{ |v| append_querystring_value(uri, "#{key}[]", v) }
      when Hash  then value.each{ |k, v| append_querystring_value(uri, "#{key}[#{k}]", v) }
      else            uri << '&' << CGI.escape(key.to_s) << '=' << CGI.escape(value.to_s)
      end
    end

    def append_querystring(uri, params)
      if params && !params.empty?
        uri_size = uri.size
        params.each{ |k,v|  append_querystring_value(uri, k, v) }
        uri[uri_size] = ??
      end
      uri
    end
  end
end