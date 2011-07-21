class HttpRouter
  class RegexRoute < Route
    def initialize(router, path, opts = {})
      @router, @original_path, @opts = router, path, opts
      @param_names = @original_path.respond_to?(:names) ? @original_path.names.map(&:to_sym) : []
      process_opts
    end

    def add_path_to_tree
      @paths = [@original_path]
      add_non_path_to_tree(@router.root.add_free_match(@original_path), path, @param_names)
    end

    def significant_variable_names
      @param_names
    end

    def match_partially?
      true
    end

    def regex?
      true
    end

    def generate_from?(params)
      false
    end
  end
end