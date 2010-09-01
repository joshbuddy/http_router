class HttpRouter
  class Path
    attr_reader :parts, :route, :splitting_indexes
    def initialize(route, path, parts, splitting_indexes)
      @route, @path, @parts, @splitting_indexes = route, path, parts, splitting_indexes
      
      duplicate_variable_names = variable_names.dup.uniq!
      raise AmbiguousVariableException, "You have duplicate variable name present: #{duplicate_variable_names.join(', ')}" if duplicate_variable_names

      @path_validation_regex = path.split(/([:\*][a-zA-Z0-9_]+)/).map{ |part|
        case part[0]
        when ?:, ?*
          route.matches_with[part[1, part.size].to_sym] || '.*?' 
        else
          Regexp.quote(part)
        end
      }.join
      @path_validation_regex = Regexp.new("^#{@path_validation_regex}$")

      eval_path = path.gsub(/[:\*]([a-zA-Z0-9_]+)/) {"\#{args.shift || (options && options.delete(:#{$1})) || raise(MissingParameterException, \"missing parameter #{$1}\")}" }
      instance_eval "
      def raw_url(args,options)
        \"#{eval_path}\"
      end
      "
    end

    def ===(other_path)
      return false if @parts.size != other_path.parts.size
      @parts.each_with_index {|p,i| 
        return unless compare_parts(p, other_path.parts[i])
      }
      true
    end

    def compare_parts(p1, p2)
      case p1
      when Glob then p2.is_a?(Glob)
      when Variable then p2.is_a?(Variable)
      else
        p1 == p2
      end
    end

    def url(args, options)
      path = raw_url(args, options)
      raise InvalidRouteException if path !~ @path_validation_regex
      raise TooManyParametersException unless args.empty?
      HttpRouter.uri_escape!(path)
      generate_querystring(path, options)
      path
    end

    def generate_querystring(uri, params)
      if params && !params.empty?
        uri_size = uri.size
        params.each do |k,v|
          case v
          when Array
            v.each { |v_part| uri << '&' << Rack::Utils.escape(k.to_s) << '%5B%5D=' << Rack::Utils.escape(v_part.to_s) }
          else
            uri << '&' << Rack::Utils.escape(k.to_s) << '=' << Rack::Utils.escape(v.to_s)
          end
        end
        uri[uri_size] = ??
      end
    end

    def variables
      unless @variables
        @variables = @parts.select{|p| p.is_a?(Variable)}
      end
      @variables
    end

    def variable_names
      @variable_names ||= variables.map{|v| v.name}
    end
  end
end
