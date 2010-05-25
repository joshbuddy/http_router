class HttpRouter
  class Route
    attr_reader :dest, :paths
    attr_accessor :trailing_slash_ignore, :partially_match, :default_values

    def initialize(base, default_values)
      @base, @default_values = base, default_values
      @paths = []
    end

    def name(name)
      @name = name
      @base.routes[name] = self
    end

    def named
      @name
    end

    def to(dest = nil, &block)
      @dest = dest || block
      self
    end

    def match_partially!(match = true)
      @partially_match = match
      self
    end
  
    def redirect(path, status = 302)
      unless (300..399).include?(status)
        raise ArgumentError, "Status has to be an integer between 300 and 399"
      end
      to { |env|
        params = env['router.params']
        response = ::Rack::Response.new
        response.redirect(eval(%|"#{path}"|), status)
        response.finish
      }
      self
    end
    
    def serves_static_from(root)
      if File.directory?(root)
        match_partially!
        to ::Rack::File.new(root)
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
      path = matching_path(args.empty? ? options : args)
      raise UngeneratableRouteException.new unless path
      path.url(args, options)
    end

    def matching_path(params)
      if @paths.size == 1
        @paths.first
      else
        if params.is_a?(Array)
          @paths.each do |path|
            if path.variables.size == params.size
              return path
            end
          end
          nil
        else
          maximum_matched_route = nil
          maximum_matched_params = -1
          @paths.each do |path|
            param_count = 0
            path.variables.each do |variable|
              if params && params.key?(variable.name)
                param_count += 1
              else
                param_count = -1
                break
              end
            end
            if (param_count != -1 && param_count > maximum_matched_params)
              maximum_matched_params = param_count;
              maximum_matched_route = path;
            end
          end
          maximum_matched_route
        end
      end
    end
  end
end
