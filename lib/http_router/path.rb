class HttpRouter
  class Path
    attr_reader :parts, :extension
    attr_accessor :route
    def initialize(path, parts, extension)
      @path, @parts, @extension = path, parts, extension
      @eval_path = path.gsub(/[:\*]([a-zA-Z0-9_]+)/) {"\#{args.shift || (options && options.delete(:#{$1})) || raise(MissingParameterException.new(\"missing parameter #{$1}\"))}" }
      instance_eval "
      def raw_url(args,options)
        \"#{@eval_path}\"
      end
      "
    end

    def url(args, options)
      path = raw_url(args, options)
      raise TooManyParametersException.new unless args.empty?
      Rack::Utils.uri_escape!(path)
      path << '?' << generate_querystring(options) if options && !options.empty?
      path
    end

    def generate_querystring(params)
      extra_params_result = ''
      params.each do |k,v|
        case v
        when Array
          v.each do |v_part|
            extra_params_result << '&' unless extra_params_result.empty?
            extra_params_result << Rack::Utils.escape(k.to_s) << '%5B%5D=' << Rack::Utils.escape(v_part.to_s)
          end
        else
          extra_params_result << '&' unless extra_params_result.empty?
          extra_params_result << Rack::Utils.escape(k.to_s) << '=' << Rack::Utils.escape(v.to_s)
        end
      end
      extra_params_result
    end

    def variables
      unless @variables
        @variables = @parts.select{|p| p.is_a?(Variable)}
        @variables << @extension if @extension.is_a?(Variable)
      end
      @variables
    end

    def variable_names
      variables.map{|v| v.name}
    end

    def matches_extension?(extension)
      @extension.nil? || @extension === (extension)
    end
  end
end
