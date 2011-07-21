require 'uri'
class HttpRouter
  class Path
    attr_reader :route, :param_names, :dynamic
    alias_method :dynamic?, :dynamic
    def initialize(route, path, param_names = [])
      @route, @path, @param_names, @dynamic = route, path, param_names, !param_names.empty?
      duplicate_param_names = param_names.dup.uniq!
      raise AmbiguousVariableException, "You have duplicate variable name present: #{duplicate_param_names.join(', ')}" if duplicate_param_names
      if path.respond_to?(:split)
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
              code << "\#{args.shift || (options && options.delete(:#{part[1, part.size]})) || return}"
            end
          else
            @path_validation_regex << Regexp.quote(part)
            code << part
          end
          new_part
        }
        @path_validation_regex = Regexp.new("^#{@path_validation_regex}$")
        instance_eval <<-EOT, __FILE__, __LINE__ + 1
        def raw_url(args, options)
          url = \"#{code}\"
          #{"url !~ @path_validation_regex ? nil : " if @dynamic} url
        end
        EOT
      end
    end

    def hashify_params(params)
      @dynamic && params ? Hash[param_names.zip(params)] : {}
    end

    def url(args, options)
      if path = raw_url(args, options)
        raise TooManyParametersException unless args.empty?
        [URI.escape(path), options]
      end
    end

    def original_path
      @path
    end

    private
    def raw_url(args, options)
      raise InvalidRouteException
    end
  end
end