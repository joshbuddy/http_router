class HttpRouter
  class RegexRoute < Route
    def initialize(router, path, opts = {})
      @router, @path, @opts = router, path, opts
    end

    def compile
      add_non_path_to_tree(@router.root.add_free_match(path), path, [])
      @compiled = true
    end

    def match_partially?
      true
    end

    def regex?
      true
    end
  end
end