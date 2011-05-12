class HttpRouter
  class Request
    attr_reader :acceptance_test
    attr_accessor :path, :params, :rack_request, :extra_env, :continue
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

    def clone
      dup_obj = super
      dup_obj.path = path.dup
      dup_obj.params = params.dup
      dup_obj.extra_env = extra_env.dup
      dup_obj
    end
  end
end