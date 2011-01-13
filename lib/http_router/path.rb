class HttpRouter
  class Path
    attr_reader :parts, :route, :splitting_indexes, :path
    def initialize(route, path, parts, splitting_indexes)
      @route, @path, @parts, @splitting_indexes = route, path, parts, splitting_indexes
      duplicate_variable_names = variable_names.dup.uniq!
      raise AmbiguousVariableException, "You have duplicate variable name present: #{duplicate_variable_names.join(', ')}" if duplicate_variable_names
      regex_parts = path.split(/([:\*][a-zA-Z0-9_]+)/)
      @path_validation_regex, code = '', ''
      regex_parts.each_with_index{ |part, index|
        new_part = case part[0]
        when ?:, ?*
          if index != 0 && regex_parts[index - 1][-1] == ?\\
            @path_validation_regex << Regexp.quote(part)
            code << part
          else
            @path_validation_regex << (route.matches_with[part[1, part.size].to_sym] || '.*?').to_s
            code << "\#{args.shift || (options && options.delete(:#{part[1, part.size]})) || raise(MissingParameterException, \"missing parameter :#{part[1, part.size]}\")}"
          end
        else
          @path_validation_regex << Regexp.quote(part)
          code << part
        end
        new_part
      }
      @path_validation_regex = Regexp.new("^#{@path_validation_regex}$")
      instance_eval "
      def raw_url(args,options)
        \"#{code}\"
      end
      "
    end

    def hashify_params(params)
      !static? && params ? variable_names.zip(params).inject({}) { |h, (k,v)| h[k] = v; h } : {}
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
      when Glob     then p2.is_a?(Glob)
      when Variable then p2.is_a?(Variable)
      else               p1 == p2
      end
    end

    def url(args, options)
      path = raw_url(args, options)
      raise InvalidRouteException if path !~ @path_validation_regex
      raise TooManyParametersException unless args.empty?
      HttpRouter.uri_escape!(path)
      [path, options]
    end

    def static?
      variables.empty?
    end

    def variables
      @variables ||= @parts.select{|p| p.is_a?(Variable)}
    end

    def variable_names
      @variable_names ||= variables.map{|v| v.name}
    end
  end
end
