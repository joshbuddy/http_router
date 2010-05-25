class HttpRouter
  class Glob < Variable
    def matches(parts, whole_path)
      if @matches_with && match = @matches_with.match(parts.first)
        params = [parts.shift]
        while !parts.empty? and match = @matches_with.match(parts.first)
          params << parts.shift
        end
        whole_path.replace(parts.join('/'))
        params
      else
        params = parts.dup
        parts.clear
        params
      end
    end
  end
end
