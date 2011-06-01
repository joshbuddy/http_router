class HttpRouter
  class Node
    autoload :Glob,          'http_router/node/glob'
    autoload :Variable,      'http_router/node/variable'
    autoload :Regex,         'http_router/node/regex'
    autoload :SpanningRegex, 'http_router/node/spanning_regex'
    autoload :GlobRegex,     'http_router/node/glob_regex'
    autoload :FreeRegex,     'http_router/node/free_regex'
    autoload :Arbitrary,     'http_router/node/arbitrary'
    autoload :Request,       'http_router/node/request'
    autoload :Lookup,        'http_router/node/lookup'
    autoload :Destination,   'http_router/node/destination'

    attr_reader :priority, :router, :node_position, :parent

    def initialize(router, parent, matchers = [])
      @router, @parent, @matchers = router, parent, matchers
    end

    def add_variable
      add(Variable.new(@router, self))
    end

    def add_glob
      add(Glob.new(@router, self))
    end

    def add_request(opts)
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

    def add_destination(blk, partial)
      add(Destination.new(@router, self, blk, partial))
    end

    def add_lookup(part)
      add(Lookup.new(@router, self)).add(part)
    end

    def usable?(other)
      false
    end

    def method_missing(m, *args, &blk)
      if m.to_s == '[]'
        compile
        send(:[], *args)
      else
        super
      end
    end

    def compile
      instance_eval "def [](request)\n#{to_code}\nnil\nend", __FILE__, __LINE__
    end

    private
    def add(matcher)
      @matchers << matcher unless matcher.usable?(@matchers.last)
      @matchers.last
    end

    def to_code
      @matchers.map{ |m| "# #{m.class}\n" << m.to_code }.join("\n") << "\n"
    end

    def depth
      p = @parent
      d = 0
      until p.nil?
        d += 1
        p = p.parent
      end
      d
    end
  end
end