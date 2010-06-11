class HttpRouter
  class Glob < Variable
    def matches?(parts)
      @matches_with.nil? or (!parts.empty? and match = @matches_with.match(parts.first) and match.begin(0))
    end

    def consume(parts)
      if @matches_with
        params = [parts.shift]
        params << parts.shift while matches?(parts)
        params
      else
        params = parts.dup
        parts.clear
        params
      end
    end
  end
end
