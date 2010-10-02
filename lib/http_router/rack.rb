class HttpRouter
  module Rack
    autoload :URLMap,  'http_router/rack/url_map'
    autoload :Builder, 'http_router/rack/buidler'

    # Monkey-patches Rack::Builder to use HttpRouter.
    # See examples/rack_mapper.rb
    def self.override_rack_builder!
      ::Rack.class_eval("OriginalBuilder = Builder; HttpRouterBuilder = HttpRouter::Rack::Builder; remove_const :Builder; Builder = HttpRouterBuilder")
    end

    # Monkey-patches Rack::URLMap to use HttpRouter.
    # See examples/rack_mapper.rb
    def self.override_rack_urlmap!
      ::Rack.class_eval("OriginalURLMap = URLMap; HttpRouterURLMap = HttpRouter::Rack::URLMap; remove_const :URLMap; URLMap = HttpRouterURLMap")
    end
  end
end