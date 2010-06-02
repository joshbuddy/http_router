class HttpRouter
  class Variable
    attr_reader :name, :matches_with

    def initialize(router, name, matches_with = nil)
      @router = router
      @name = name
      @matches_with = matches_with
    end

    def matches?(parts, whole_path)
      @matches_with.nil? or (@matches_with and match = @matches_with.match(whole_path) and match.begin(0) == 0)
    end

    def consume(parts, whole_path)
      if @matches_with
        match = @matches_with.match(whole_path)
        parts.replace(router.split(whole_path[match.end(0), whole_path.size]))
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
