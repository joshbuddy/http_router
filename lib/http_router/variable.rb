class HttpRouter
  class Variable
    attr_reader :name, :matches_with

    def initialize(base, name, matches_with = nil)
      @base = base
      @name = name
      @matches_with = matches_with
    end
    
    def matches(parts, whole_path)
      if @matches_with.nil?
        parts.first
      elsif @matches_with && match = @matches_with.match(whole_path)
        whole_path.slice!(0, match[0].size)
        parts.replace(@base.split(whole_path))
        match[0]
      end
    end
    
    def ===(part)
      @matches_with.nil?
    end
    
  end
end
