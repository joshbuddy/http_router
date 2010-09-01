class HttpRouter
  class Glob < Variable
    def matches?(parts)
      return if @matches_with.nil? or parts.empty? or !match.begin(0)
      @matches_with.match(parts.first)
    end

    def consume(match, parts)
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
