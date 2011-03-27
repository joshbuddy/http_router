class HttpRouter
  module Rack
    autoload :URLMap,       'http_router/rack/url_map'
    autoload :Builder,      'http_router/rack/builder'
    autoload :BuilderMixin, 'http_router/rack/builder'

    # Monkey-patches Rack::Builder to use HttpRouter.
    # See examples/rack_mapper.rb
    def self.override_rack_builder!
      ::Rack::Builder.class_eval("remove_method :map; include HttpRouter::Rack::BuilderMixin")
    end

    # Monkey-patches Rack::URLMap to use HttpRouter.
    # See examples/rack_mapper.rb
    def self.override_rack_urlmap!
      ::Rack.class_eval("OriginalURLMap = URLMap; HttpRouterURLMap = HttpRouter::Rack::URLMap; remove_const :URLMap; URLMap = HttpRouterURLMap")
    end
  end
end