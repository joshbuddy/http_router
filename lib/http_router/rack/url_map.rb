require 'http_router'

class HttpRouter
  module Rack
    class URLMap < ::Rack::URLMap
      def initialize(map = {})
        @router = HttpRouter.new
        map.each { |path, app| (path =~ /^(https?):\/\/(.*?)(\/.*)/ ? @router.add($3).host($2).scheme($1) : @router.add(path)).partial.to(app) }
      end

      def call(env)
        @router.call(env)
      end
    end
  end
end