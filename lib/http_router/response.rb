class HttpRouter
  class Response < Struct.new(:request, :path)
    attr_reader :params
    def initialize(request, path)
      super(request, path)
      @params = path.hashify_params(request.params)
    end

    def param_values
      request.params
    end
  end
end