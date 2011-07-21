require 'http_router'

# Replacement for {Rack::Builder} which using HttpRouter to map requests instead of a simple Hash.
# As well, add convenience methods for the request methods.
module HttpRouter::Rack::BuilderMixin
  def router
    @router ||= HttpRouter.new
  end

  # Maps a path to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def map(path, options = {}, method = nil, &block)
    route = router.add(path, options)
    route.send(method) if method
    route.to(&block)
    @ins << router unless @ins.last == router
    route
  end

  # Maps a path with request methods `HEAD` and `GET` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def get(path, options = {}, &block)
    map(path, options, :get, &block)
  end

  # Maps a path with request methods `POST` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def post(path, options = {}, &block)
    map(path, options, :post, &block)
  end

  # Maps a path with request methods `PUT` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def put(path, options = {}, &block)
    map(path, options, :put, &block)
  end

  # Maps a path with request methods `DELETE` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def delete(path, options = {}, &block)
    map(path, options, :delete, &block)
  end

  def options(path, options = {}, &block)
    map(path, options, :options, &block)
  end
end

class HttpRouter::Rack::Builder < ::Rack::Builder
  include HttpRouter::Rack::BuilderMixin
end