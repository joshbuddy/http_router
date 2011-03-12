class HttpRouter
  class RegexRoute < Route
    def initialize(router, path, opts = {})
      @router, @path, @opts = router, path, opts
      @router.root.add_free_match(path).add_destination(Path.new(self, path, []))
      @compiled = true
    end

    def match_partially?
      true
    end

  end
end