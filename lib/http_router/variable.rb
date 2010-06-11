class HttpRouter
  class Variable
    attr_reader :name, :matches_with

    def initialize(router, name, matches_with = nil)
      @router = router
      @name = name
      @matches_with = matches_with
    end

    def matches?(parts)
      @matches_with.nil? or (@matches_with and match = @matches_with.match(parts.whole_path) and match.begin(0) == 0) ? match : nil
    end

    def consume(match, parts)
      if @matches_with
        parts.replace(router.split(parts.whole_path[match.end(0), parts.whole_path.size]))
        match[0]
      else
        parts.shift
      end
    end

    def ===(part)
      @matches_with.nil?
    end

    protected
      attr_reader :router
  end
end
