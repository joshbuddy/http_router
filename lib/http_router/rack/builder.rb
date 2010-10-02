# Replacement for {Rack::Builder} which using HttpRouter to map requests instead of a simple Hash.
# As well, add convenience methods for the request methods.
class HttpRouter::Rack::Builder < ::Rack::Builder
  def initialize(&block)
    super
  end
  
  def router
    @router ||= HttpRouter.new
  end

  # Maps a path to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def map(path, options = nil, &block)
    router.add(path).with_options(options).to(&block)
    @ins << router unless @ins.last == router
  end

  # Maps a path with request methods `HEAD` and `GET` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def get(path, options = nil, &block)
    router.get(path).with_options(options).to(&block)
  end

  # Maps a path with request methods `POST` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def post(path, options = nil, &block)
    router.post(path).with_options(options).to(&block)
  end

  # Maps a path with request methods `PUT` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def put(path, options = nil, &block)
    router.put(path).with_options(options).to(&block)
  end

  # Maps a path with request methods `DELETE` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def delete(path, options = nil, &block)
    router.delete(path).with_options(options).to(&block)
  end

  # Maps a path with request methods `HEAD` to a block.
  # @param path [String] Path to map to.
  # @param options [Hash] Options for added path.
  # @see HttpRouter#add
  def head(path, options = nil, &block)
    router.head(path).with_options(options).to(&block)
  end
end
