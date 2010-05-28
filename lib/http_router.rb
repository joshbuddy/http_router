$LOAD_PATH << File.dirname(__FILE__)
require 'rack'
require 'ext/rack/uri_escape'

class HttpRouter
  autoload :Node,     'http_router/node'
  autoload :Root,     'http_router/root'
  autoload :Variable, 'http_router/variable'
  autoload :Glob,     'http_router/glob'
  autoload :Route,    'http_router/route'
  autoload :Response, 'http_router/response'
  autoload :Path,     'http_router/path'

  UngeneratableRouteException = Class.new(RuntimeError)
  MissingParameterException   = Class.new(RuntimeError)
  TooManyParametersException  = Class.new(RuntimeError)
  AlreadyCompiledException    = Class.new(RuntimeError)
  RoutingResponse             = Struct.new(:status, :headers)

  attr_reader :named_routes, :routes, :root

  def initialize(options = nil)
    @default_app = options && options[:default_app] || proc{|env| ::Rack::Response.new("Not Found", 404).finish }
    @ignore_trailing_slash   = options && options.key?(:ignore_trailing_slash) ? options[:ignore_trailing_slash] : true
    @redirect_trailing_slash = options && options.key?(:redirect_trailing_slash) ? options[:redirect_trailing_slash] : false
    @routes = []
    @named_routes = {}
    reset!
  end

  def ignore_trailing_slash?
    @ignore_trailing_slash
  end

  def redirect_trailing_slash?
    @redirect_trailing_slash
  end

  def reset!
    @root = Root.new(self)
    @routes.clear
    @named_routes.clear
  end

  def default(app)
    @default_app = app
  end
  
  def split(path, with_delimiter = false)
    path.slice!(0) if path[0] == ?/
    with_delimiter ? path.split('(/)') : path.split('/')
  end

  def add(path)
    route = Route.new(self, path.dup)
    @routes << route
    route
  end

  def get(path)
    add(path).get
  end

  def post(path)
    add(path).post
  end

  def put(path)
    add(path).put
  end

  def delete(path)
    add(path).delete
  end

  def only_get(path)
    add(path).only_get
  end

  def recognize(env)
    response = @root.find(env.is_a?(Hash) ? Rack::Request.new(env) : env)
  end

  def url(route, *args)
    case route
      when Symbol
        url(@named_routes[route], *args)
      when nil
        raise UngeneratableRouteException.new
      else
        route.url(*args)
    end
  end

  def call(env)
    request = Rack::Request.new(env)
    if redirect_trailing_slash? && (request.head? || request.get?) && request.path_info[-1] == ?/
      response = Rack::Response.new
      response.redirect(request.path_info[0, request.path_info.size - 1], 302)
      response.finish
    else
      response = recognize(request)
      env['router'] = self
      if response.is_a?(RoutingResponse)
        [response.status, response.headers, []]
      elsif response && response.route.dest && response.route.dest.respond_to?(:call)
        process_params(env, response)
        consume_path!(request, response) if response.partial_match?
        response.route.dest.call(env)
      else
        @default_app.call(env)
      end
    end
  end

  private

  def consume_path!(request, response)
    request.env["SCRIPT_NAME"] = (request.env["SCRIPT_NAME"] + response.matched_path)
    request.env["PATH_INFO"] = response.remaining_path || ""
  end

  def process_params(env, response)
    if env.key?('router.params')
      env['router.params'].merge!(response.route.default_values) if response.route.default_values
      env['router.params'].merge!(response.params_as_hash)
    else
      env['router.params'] = response.route.default_values ? response.route.default_values.merge(response.params_as_hash) : response.params_as_hash
    end
  end

end
