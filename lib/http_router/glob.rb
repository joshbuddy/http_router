class HttpRouter
  class Glob < Variable

    def matches?(parts, whole_path)
      @matches_with.nil? or (!parts.empty? and match = @matches_with.match(parts.first) and match.begin(0))
    end

    def consume(parts, whole_path)
      if @matches_with
        params = [parts.shift]
        params << parts.shift while matches?(parts, whole_path)
        params
      else
        params = parts.dup
        parts.clear
        params
      end
    end
  end
end
