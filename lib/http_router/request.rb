class HttpRouter
  class Request
    attr_reader :extra_env, :perform_call
    attr_accessor :path, :params, :rack_request
    def initialize(path, rack_request, perform_call)
      @path = (path[0] == ?/ ? path[1, path.size] : path).split(/\//)
      @path << '' if path.size > 1 && path[-1] == ?/
      @rack_request, @perform_call = rack_request, perform_call
      @extra_env = {}
      @params = []
    end
  
    def to_s
      "request path, #{path.inspect}"
    end
    
    def clone
      dup_obj = super
      dup_obj.path = path.dup
      dup_obj.params = params.dup
      dup_obj
    end
  end
end