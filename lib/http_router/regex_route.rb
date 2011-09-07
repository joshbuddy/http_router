class HttpRouter
  class RegexRoute < Route
    def initialize(router, path, opts = nil)
      @router, @original_path, @opts = router, path, opts
      @param_names = @original_path.respond_to?(:names) ? @original_path.names.map(&:to_sym) : []
      @path_validation_regex = original_path
      Util.add_path_generation(self, self, opts.delete(:path_for_generation), @original_path) if opts.key?(:path_for_generation)
      process_opts if opts
    end

    def compile
      @paths = [@original_path]
      add_non_path_to_tree(@router.root.add_free_match(@original_path), @original_path, @param_names)
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

    def url_with_params(*a)
      url_args_processing(a) do |args, options|
        respond_to?(:raw_url) or raise InvalidRouteException
        raw_url(args, options)
      end
    end
  end
end