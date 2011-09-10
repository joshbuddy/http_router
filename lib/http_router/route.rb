require 'set'

class HttpRouter
  class Route
    VALID_HTTP_VERBS = %w{GET POST PUT DELETE HEAD OPTION}

    attr_reader :default_values, :router, :match_partially, :other_hosts, :paths, :request_methods, :path, :schemes
    attr_accessor :match_partially, :router, :host,
      :user_agent, :name, :ignore_trailing_slash, :significant_variable_names,
      :path_for_generation, :path_validation_regex

    def add_default_values(hash)
      @default_values ||= {}
      @default_values.merge!(hash)
    end

    def dest
      @dest
    end

    def dest=(d)
      @dest = d
    end

    def add_match_with(matchers)
      @match_with ||= {}
      @match_with.merge!(matchers)
    end

    def add_other_host(hosts)
      (@other_hosts ||= []).concat(hosts)
    end

    def add_path(path)
      (@paths ||= []) << path
    end

    def add_scheme(scheme)
      (@schemes ||= []) << scheme
    end

    def add_request_method(methods)
      @request_methods ||= Set.new
      methods = [methods] unless methods.is_a?(Array)
      methods.each do |method|
        method = method.to_s.upcase
        raise unless VALID_HTTP_VERBS.include?(method)
        @router.known_methods << method
        @request_methods << method
      end
    end

    def url(*args)
      result, extra_params = url_with_params(*args)
      append_querystring(result, extra_params)
    end

    def clone(new_router)
      r = super()
      r.dest = (begin; dest.clone; rescue; dest; end)
      r
    end

    def significant?(name)
      @significant_variable_names && @significant_variable_names.include?(name.to_sym)
    end

    def to_s
      "#<HttpRouter:Route #{object_id} @path=#{path.inspect}>"
    end

    def matches_with(var_name)
      @match_with && @match_with[:"#{var_name}"]
    end

    def path=(path)
      @path = path.dup
      if @path.is_a?(String)
        @significant_variable_names = path ?
          path.scan(/(^|[^\\])[:\*]([a-zA-Z0-9_]+)/).map{|p| p.last.to_sym} : []
        @path[0, 0] = '/' unless @path[0] == ?/
        if @path[/[^\\]\*$/]
          @match_partially = true
          @path.slice!(-1)
        end
      end
    end

    def name=(name)
      @name = name
      @router.named_routes[name] << self
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