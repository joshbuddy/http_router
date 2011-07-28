class HttpRouter
  module Util
    def self.add_path_generation(target, route, path, path_validation_regex = nil)
      regex_parts = path.split(/([:\*][a-zA-Z0-9_]+)/)
      regex, code = '', ''
      dynamic = false
      regex_parts.each_with_index do |part, index|
        case part[0]
        when ?:, ?*
          if index != 0 && regex_parts[index - 1][-1] == ?\\
            regex << Regexp.quote(part) unless path_validation_regex
            code << part
            dynamic = true
          else
            regex << (route.matches_with[part[1, part.size].to_sym] || '.*?').to_s unless path_validation_regex
            code << "\#{args.shift || (options && options.delete(:#{part[1, part.size]})) || return}"
            dynamic = true
          end
        else
          regex << Regexp.quote(part) unless path_validation_regex
          code << part
        end
      end
      path_validation_regex ||= Regexp.new("^#{regex}$") if dynamic
      if path_validation_regex
        target.instance_eval <<-EOT, __FILE__, __LINE__ + 1
        def raw_url(args, options)
          url = \"#{code}\"
          #{path_validation_regex.inspect}.match(url) ? url : nil
        end
        EOT
      else
        target.instance_eval <<-EOT, __FILE__, __LINE__ + 1
        def raw_url(args, options)
          \"#{code}\"
        end
        EOT
      end
    end
  end
end