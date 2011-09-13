class HttpRouter
  class Generator
    SCHEME_PORTS = {'http' => 80, 'https' => 443}

    class PathGenerator
      attr_reader :path, :param_names
      def initialize(route, path, validation_regex = nil)
        @route = route
        @path = path.dup
        puts "path is a string? #{@path.is_a?(String)}"
        @param_names = if @path.respond_to?(:names)
          @path.names.map(&:to_sym)
        elsif path.is_a?(String)
          @path.scan(/(^|[^\\])[:\*]([a-zA-Z0-9_]+)/).map{|p| p.last.to_sym}
        else
          []
        end
        puts "path #{@path.inspect} #{@param_names.inspect}"

        if path.is_a?(String)
          path[0, 0] = '/' unless path[0] == ?/
          regex_parts = path.split(/([:\*][a-zA-Z0-9_]+)/)
          regex, code = '', ''
          dynamic = false
          regex_parts.each_with_index do |part, index|
            case part[0]
            when ?:, ?*
              if index != 0 && regex_parts[index - 1][-1] == ?\\
                regex << Regexp.quote(part) unless validation_regex
                code << part
                dynamic = true
              else
                regex << (@route.matches_with(part[1, part.size].to_sym) || '.*?').to_s unless validation_regex
                code << "\#{args.shift || (options && options.delete(:#{part[1, part.size]})) || return}"
                dynamic = true
              end
            else
              regex << Regexp.quote(part) unless validation_regex
              code << part
            end
          end
          validation_regex ||= Regexp.new("^#{regex}$") if dynamic
          if validation_regex
            instance_eval <<-EOT, __FILE__, __LINE__ + 1
            def generate(args, options)
              puts 'generating!'
              puts "args: \#{args.inspect}"
              puts "options: \#{options.inspect}"
              generated_path = \"#{code}\"
              puts "after .. args: \#{args.inspect}"
              puts "generated path \#{generated_path.inspect}"
              p #{validation_regex.inspect}.match(generated_path)
              #{validation_regex.inspect}.match(generated_path) ? generated_path : nil
            end
            EOT
          else
            instance_eval <<-EOT, __FILE__, __LINE__ + 1
            def generate(args, options)
              \"#{code}\"
            end
            EOT
          end
        end
      end
    end

    attr_reader :param_names
    def initialize(route, paths)
      @route, @paths = route, paths
      @router = @route.router
      @route.generator = self
      @path_generators = @paths.map do |p|
        generator = PathGenerator.new(route, p.is_a?(String) ? p : route.path_for_generation, p.is_a?(Regexp) ? p : nil)
      end
    end

    def max_param_count
      @max_param_count ||= @path_generators.map{|p| p.param_names.size}.max
    end

    def each_path
      @path_generators.each {|p| yield p.path, p.param_names}
    end

    def full_url(*args)
      "#{scheme_port.first}#{url(*args)}"
    end

    def url(*args)
      "://#{@route.host || @router.default_host}#{scheme_port.last}#{path(*args)}"
    end

    def path(*args)
      result, extra_params = path_with_params(*args)
      append_querystring(result, extra_params)
    end

    private
    def scheme_port
      @scheme_port ||= begin
        scheme = @route.scheme || @router.default_scheme
        port = @router.default_port
        port_part = SCHEME_PORTS.key?(scheme) && SCHEME_PORTS[scheme] == port ? '' : ":#{port}"
        [scheme, port_part]
      end
    end

    def path_with_params(*a)
      path_args_processing(a) do |args, options|
        path = args.empty? ? matching_path(options) : matching_path(args, options)
        path &&= path.generate(args, options)
        puts "path is #{path.inspect}"
        raise TooManyParametersException unless args.empty?
        raise InvalidRouteException.new("Error generating #{@route.path_for_generation}") unless path
        path ? [path, options] : nil
      end
    end

    def path_args_processing(args)
      options = args.last.is_a?(Hash) ? args.pop : nil
      options = options.nil? ? @route.default_values.dup : @route.default_values.merge(options) if @route.default_values
      options.delete_if{ |k,v| v.nil? } if options
      result, params = yield args, options
      mount_point = @router.url_mount && (options ? @router.url_mount.url(options) : @router.url_mount.url)
      mount_point ? [File.join(mount_point, result), params] : [result, params]
    end

    def matching_path(params, other_hash = nil)
      return @path_generators.first if @path_generators.size == 1
      case params
      when Array, nil
        significant_keys = other_hash && param_names & other_hash.keys
        @path_generators.find { |path|
          params_size = params ? params.size : 0
          path.param_names.size == (significant_keys ? (params_size) + significant_keys.size : params_size) }
      when Hash
        @path_generators.find { |path| p path.param_names; (params && !params.empty? && (path.param_names & params.keys).size == path.param_names.size) || path.param_names.empty? }
      end
    end

    def append_querystring_value(uri, key, value)
      case value
      when Array then value.each{ |v|    append_querystring_value(uri, "#{key}[]",     v) }
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