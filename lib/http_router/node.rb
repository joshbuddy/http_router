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

    attr_reader :priority, :router, :node_position

    def initialize(router, matchers = [])
      @router, @matchers = router, matchers
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
      add(Lookup.new(@router)).add(part)
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
      instance_eval "def [](r0)\n#{to_code(0)}\nnil\nend", __FILE__, __LINE__
    end

    private
    def add(matcher)
      @matchers << matcher unless matcher.usable?(@matchers.last)
      @matchers.last
    end

    def to_code(pos)
      spacer = "#{'  ' * pos}"
      code = "#{spacer}# --> to_code for #{self.class} #{@node_position}\n"
      @matchers.each do |m|
        code << m.to_code(pos)
      end
      code << "\n"
    end

    def indented_code(pos, code)
      indent_size = code[/^ */].size
      "\n" << code.strip.split(/\n/).map{|line| "#{'  ' * pos.next}#{line[/[ ]{#{indent_size}}(.*)/, 1]}"}.join("\n") << "\n"
    end
  end
end