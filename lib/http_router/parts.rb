class HttpRouter
  class Parts < Array
    SLASH = '/'.freeze
    SLASH_RX = Regexp.new(SLASH)
    
    def initialize(path)
      super((path[0] == ?/ ? path[1, path.size] : path).split(SLASH_RX))
    end

    def whole_path
      @whole_path ||= join(SLASH)
    end

    def shift
      @whole_path = nil
      super
    end

    def replace(ary)
      @whole_path = nil
      super
    end
  end
end