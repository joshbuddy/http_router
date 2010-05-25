class HttpRouter
  class Path
    attr_reader :parts, :extension
    attr_accessor :route
    def initialize(path, parts, extension)
      @path, @parts, @extension = path, parts, extension
      @eval_path = path.gsub(/[:\*]([a-zA-Z0-9_]+)/) {"\#{args.shift || (options && options[:#{$1}]) || raise(MissingParameterException.new(\"missing parameter #{$1}\"))}" }
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
      path
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
