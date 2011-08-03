class HttpRouter
  class Node
    autoload :Root,          'http_router/node/root'
    autoload :Glob,          'http_router/node/glob'
    autoload :GlobRegex,     'http_router/node/glob_regex'
    autoload :Variable,      'http_router/node/variable'
    autoload :Regex,         'http_router/node/regex'
    autoload :SpanningRegex, 'http_router/node/spanning_regex'
    autoload :GlobRegex,     'http_router/node/glob_regex'
    autoload :FreeRegex,     'http_router/node/free_regex'
    autoload :Arbitrary,     'http_router/node/arbitrary'
    autoload :Request,       'http_router/node/request'
    autoload :Lookup,        'http_router/node/lookup'
    autoload :Path,          'http_router/node/path'

    attr_reader :router

    def initialize(router, parent, matchers = [])
      @router, @parent, @matchers = router, parent, matchers
    end

    def add_variable
      add(Variable.new(@router, self))
    end

    def add_glob
      add(Glob.new(@router, self))
    end

    def add_glob_regexp(matcher)
      add(GlobRegex.new(@router, self, matcher))
    end

    def add_request(opts)
      raise unless opts
      add(Request.new(@router, self, opts))
    end

    def add_arbitrary(blk, allow_partial, param_names)
      add(Arbitrary.new(@router, self, allow_partial, blk, param_names))
    end

    def add_match(regexp, matching_indicies = [0], splitting_indicies = nil)
      add(Regex.new(@router, self, regexp, matching_indicies, splitting_indicies))
    end

    def add_spanning_match(regexp, matching_indicies = [0], splitting_indicies = nil)
      add(SpanningRegex.new(@router, self, regexp, matching_indicies, splitting_indicies))
    end

    def add_free_match(regexp)
      add(FreeRegex.new(@router, self, regexp))
    end

    def add_destination(route, path, param_names = [])
      add(Path.new(@router, self, route, path, param_names))
    end

    def add_lookup(part)
      add(Lookup.new(@router, self)).add(part)
    end

    def usable?(other)
      false
    end

    def inspect
      ins = "#{' ' * depth}#{inspect_label}"
      body = inspect_matchers_body
      unless body =~ /^\s*$/
        ins << "\n" << body
      end
      ins
    end

    def inspect_label
      "#{self.class.name.split("::").last} (#{@matchers.size} matchers)"
    end

    def inspect_matchers_body
      @matchers.map{ |m| m.inspect}.join("\n")
    end

    def depth
      @parent.send(:depth) + 1
    end

    private
    def inject_root_methods(code = nil, &blk)
      code ? root.methods_module.module_eval(code) : root.methods_module.module_eval(&blk)
    end

    def inject_root_ivar(obj)
      root.inject_root_ivar(obj)
    end

    def add(matcher)
      @matchers << matcher unless matcher.usable?(@matchers.last)
      @matchers.last
    end

    def to_code
      @matchers.map{ |m| "# #{m.class}\n" << m.to_code }.join("\n") << "\n"
    end

    def root
      @router.root
    end

    def use_named_captures?
      //.respond_to?(:names)
    end
  end
end