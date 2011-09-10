class HttpRouter
  module RegexRouteGeneration
    def url_with_params(*a)
      url_args_processing(a) do |args, options|
        respond_to?(:raw_url) or raise InvalidRouteException
        raw_url(args, options)
      end
    end
  end
end