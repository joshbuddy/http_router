class HttpRouter
  module GenerationHelper
    def max_param_count
      @generator.max_param_count
    end

    def url(*args)
      @generator.url(*args)
    rescue InvalidRouteException
      nil
    end

    def url_ns(*args)
      @generator.url_ns(*args)
    rescue InvalidRouteException
      nil
    end

    def path(*args)
      @generator.path(*args)
    rescue InvalidRouteException
      nil
    end

    def param_names
      @generator.param_names
    end
  end
end
