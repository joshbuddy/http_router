class HttpRouter
  class Variable
    attr_reader :name, :matches_with

    def initialize(base, name, matches_with = nil, additional_matchers = nil)
      @router = base
      @name = name
      @matches_with = matches_with
      @additional_matchers = additional_matchers
    end

    def matches(env, parts, whole_path)
      if @matches_with.nil?
        additional_matchers(env, parts.first) ? parts.first : nil
      elsif @matches_with and match = @matches_with.match(whole_path) and additional_matchers(env, parts.first)
        whole_path.slice!(0, match[0].size)
        parts.replace(router.split(whole_path))
        match[0]
      end
    end

    def additional_matchers(env, test)
      @additional_matchers.nil? || @additional_matchers.all?{|m| m.call(env, test)}
    end

    def ===(part)
      @matches_with.nil?
    end

    protected
      attr_reader :router
  end
end
