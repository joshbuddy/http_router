class HttpRouter
  class Parts < Array
    def initialize(path)
      super((path[0] == ?/ ? path[1, path.size] : path).split('/'))
    end

    def whole_path
      @whole_path ||= join('/')
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