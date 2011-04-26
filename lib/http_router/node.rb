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

    attr_reader :priority, :router

    def initialize(router, matchers = [])
      @router, @matchers = router, matchers
    end

    def [](request)
      @matchers.each {|m| m[request] }
      nil
    end

    def add_variable
      add(Variable.new(@router))
    end

    def add_glob
      add(Glob.new(@router))
    end

    def add_request(opts)
      add(Request.new(@router, opts))
    end

    def add_arbitrary(blk, allow_partial, param_names)
      add(Arbitrary.new(@router, allow_partial, blk, param_names))
    end

    def add_match(regexp, matching_indicies = [0], splitting_indicies = nil)
      add(Regex.new(@router, regexp, matching_indicies, splitting_indicies))
    end

    def add_spanning_match(regexp, matching_indicies = [0], splitting_indicies = nil)
      add(SpanningRegex.new(@router, regexp, matching_indicies, splitting_indicies))
    end

    def add_free_match(regexp)
      add(FreeRegex.new(@router, regexp))
    end

    def add_destination(blk, partial)
      add(Destination.new(@router, blk, partial))
    end

    def add_lookup(part)
      add(Lookup.new(@router)) unless @matchers.last.is_a?(Lookup)
      @matchers.last.add(part)
    end

    private
    def add(matcher)
      @matchers << matcher
      @matchers.last
    end

    def unescape(val)
      val.to_s.gsub!(/((?:%[0-9a-fA-F]{2})+)/n){ [$1.delete('%')].pack('H*') }
      val
    end
  end
end