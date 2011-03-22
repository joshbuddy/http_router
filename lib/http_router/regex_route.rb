class HttpRouter
  class RegexRoute < Route
    def initialize(router, path, opts = {})
      @router, @original_path, @opts = router, path, opts
    end

    def compile
      @param_names = @original_path.respond_to?(:names) ? @original_path.names.map(&:to_sym) : []
      add_non_path_to_tree(@router.root.add_free_match(@original_path), path, @param_names)
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