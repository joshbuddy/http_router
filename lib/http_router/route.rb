class HttpRouter
  class Route
    attr_reader :default_values, :router, :conditions, :original_path, :match_partially, :dest, :regex, :name, :matches_with, :dest, :significant_variable_names
    alias_method :match_partially?, :match_partially
    alias_method :regex?, :regex

    def initialize(router, original_path, opts = nil)
      @router, @original_path, @opts = router, original_path, opts
      process_path
      process_opts if opts
      process_match_with
      post_process
    end

    def name=(name)
      @name = name
      @router.named_routes[name] << self
      @router.named_routes[name].sort!{|r1, r2| r2.significant_variable_names.size <=> r1.significant_variable_names.size }
    end

    def redirect(path, status = 302)
      raise ArgumentError, "Status has to be an integer between 300 and 399" unless (300..399).include?(status)
      to { |env|
        params = env['router.params']
        response = ::Rack::Response.new
        response.redirect(eval(%|"#{path}"|), status)
        response.finish
      }
    end

    # Sets the destination of this route to serve static files from either a directory or a single file.
    def static(root)
      @match_partially = true if File.directory?(root)
      to File.directory?(root) ?
        ::Rack::File.new(root) :
        proc {|env| 
          env['PATH_INFO'] = File.basename(root)
          ::Rack::File.new(File.dirname(root)).call(env)
        }
    end

    def to(dest = nil, &dest_block)
      @dest = dest || dest_block || raise("you didn't specify a destination")
      if @dest.respond_to?(:url_mount=)
        urlmount = UrlMount.new(original_path, @default_values || {})
        urlmount.url_mount = router.url_mount if router.url_mount
        dest.url_mount = urlmount
      end
      self
    end

    def url(*args)
      result, extra_params = url_with_params(*args)
      append_querystring(result, extra_params)
    end

    def clone(new_router)
      r = Route.new(new_router, @original_path.dup, :__match_with__ => @matches_with, :__conditions__ => @conditions, :__default_values__ => @default_values, :__name__ => @name, :__partial__ => @partially_match).to(dest)
      r.to(begin; dest.clone; rescue; dest; end)
    end

    def to_s
      "#<HttpRouter:Route #{object_id} @original_path=#{@original_path.inspect} @conditions=#{@conditions.inspect}>"
    end

    private
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
      mount_point = router.url_mount && (options ? router.url_mount.url(options) : router.url_mount.url)
      mount_point ? [File.join(mount_point, result), params] : [result, params]
    end

    def matching_path(params, other_hash = nil)
      return @paths.first if @paths.size == 1
      case params
      when Array, nil
        significant_keys = other_hash && significant_variable_names & other_hash.keys
        @paths.find { |path| 
          params_size = params ? params.size : 0
          path.param_names.size == (significant_keys ? (params_size) + significant_keys.size : params_size) }
      when Hash
        @paths.find { |path| (params && !params.empty? && (path.param_names & params.keys).size == path.param_names.size) || path.param_names.empty? }
      end
    end

    def add_to_contitions(name, *vals)
      ((@conditions ||= {})[name] ||= []).concat(vals.flatten)
      self
    end

    def process_path
      @path_for_processing = @original_path && @original_path.dup
      if @path_for_processing
        @match_partially = true and @path_for_processing.slice!(-1) if @path_for_processing[/[^\\]\*$/]
        @path_for_processing[0, 0] = '/'                  if @path_for_processing[0] != ?/
      else
        @match_partially = true
      end
      @significant_variable_names = @path_for_processing.nil? ? [] : @original_path.scan(/(^|[^\\])[:\*]([a-zA-Z0-9_]+)/).map{|p| p.last.to_sym}
    end

    def post_process
      raise LeftOverOptions.new("There are still options left, #{@opts.inspect}") unless @opts.empty?
    end

    def process_opts
      @default_values  = @opts.delete(:__default_values__) || @opts.delete(:default_values)
      @matches_with    = significant_variable_names.include?(:match_with) ?
                           @opts :
                           @opts.delete(:__match_with__)   || @opts.delete(:match_with)
      @conditions      = @opts.delete(:__conditions__)     || @opts.delete(:conditions)
      if @match_partially.nil?
        @match_partially = @opts.delete(:__partial__) if @opts.key?(:__partial__)
        @match_partially = @opts.delete(:partial)     if @opts.key?(:partial) && match_partially.nil?
      end
      self.name            = @opts.delete(:__name__)           || @opts.delete(:name)
      add_to_contitions :request_method, @opts.delete(:request_method) if @opts.key?(:request_method)
      add_to_contitions :host, @opts.delete(:host) if @opts.key?(:host)
      add_to_contitions :scheme, @opts.delete(:scheme) if @opts.key?(:scheme)
      add_to_contitions :user_agent, @opts.delete(:user_agent) if @opts.key?(:user_agent)
    end

    def process_match_with
      significant_variable_names.each do |name|
        (@matches_with ||= {})[name] = @opts.delete(name) if @opts.key?(name) && (@matches_with.nil? || !@matches_with.key?(name))
      end
    end

    def raw_paths
      return [] if @original_path.nil?
      @raw_paths ||= begin
        start_index, end_index = 0, 1
        @raw_paths, chars = [""], @path_for_processing.split('')
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
        @matches_with && @matches_with[name.to_sym] ? node.add_spanning_match(@matches_with[name.to_sym]) : node.add_variable
      when ?*
        param_names << name.to_sym
        @matches_with && @matches_with[name.to_sym] ? node.add_glob_regexp(@matches_with[name.to_sym]) : node.add_glob
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
            @matches_with && @matches_with[name] ? "((?:#{@matches_with[name]}\\/?)+)" : '(.*?)'
          else
            "(#{(@matches_with && @matches_with[name] || '[^/]*?')})"
          end
        else
          Regexp.quote(part)
        end
      end
      spans ? node.add_spanning_match(Regexp.new("#{regex}$"), capturing_indicies, splitting_indicies) :
        node.add_match(Regexp.new("#{regex}$"), capturing_indicies, splitting_indicies)
    end

    def compile
      @paths = if raw_paths.empty?
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

    def add_non_path_to_tree(node, path, names)
      node = node.add_request(@conditions) if @conditions && !@conditions.empty?
      path_obj = node.add_destination(self, path, names)
      path_obj
    end

    def append_querystring_value(uri, key, value)
      case value
      when Array then value.each{ |v| append_querystring_value(uri, "#{key}[]", v) }
      when Hash  then value.each{ |k, v| append_querystring_value(uri, "#{key}[#{k}]", v) }
      else            uri << "&#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
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