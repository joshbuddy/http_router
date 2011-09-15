class HttpRouter
  class Request
    attr_accessor :path, :params, :rack_request, :extra_env, :continue, :passed_with
    attr_reader :as_iterator, :matches
    alias_method :rack, :rack_request
    def initialize(path, rack_request, as_iterator)
      @rack_request, @as_iterator = rack_request, as_iterator
      @path = URI.unescape(path).split(/\//)
      @path.shift if @path.first == ''
      @path.push('') if path[-1] == ?/
      @extra_env = {}
      @params = []
      @matches = []
    end

    def joined_path
      @path * '/'
    end

    def matched_route(response)
      @matches << response
    end

    def to_s
      "request path, #{path.inspect}"
    end

    def path_finished?
      @path.size == 0 or @path.size == 1 && @path.first == ''
    end
  end
end