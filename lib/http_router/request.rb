class HttpRouter
  class Request
    attr_reader :acceptance_test
    attr_accessor :path, :params, :rack_request, :extra_env, :continue, :passed_with
    alias_method :rack, :rack_request
    def initialize(path, rack_request, perform_call, &acceptance_test)
      @rack_request, @perform_call, @acceptance_test = rack_request, perform_call, acceptance_test
      @path = (path[0] == ?/ ? path[1, path.size] : path).split(/\//)
      @path << '' if path.size > 1 && path[-1] == ?/
      @extra_env = {}
      @params = []
    end

    def joined_path
      @path * '/'
    end

    def perform_call
      @perform_call == true
    end

    def testing_405?
      @perform_call == 405
    end

    def to_s
      "request path, #{path.inspect}"
    end

    def path_finished?
      @path.size == 0 or @path.size == 1 && @path.first == ''
    end
  end
end