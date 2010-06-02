$LOAD_PATH << File.dirname(__FILE__)
require 'rack'
require 'ext/rack/uri_escape'

class HttpRouter
  autoload :Node,             'http_router/node'
  autoload :Root,             'http_router/root'
  autoload :Variable,         'http_router/variable'
  autoload :Glob,             'http_router/glob'
  autoload :Route,            'http_router/route'
  autoload :Response,         'http_router/response'
  autoload :Path,             'http_router/path'
  autoload :OptionalCompiler, 'http_router/optional_compiler'

  UngeneratableRouteException      = Class.new(RuntimeError)
  MissingParameterException        = Class.new(RuntimeError)
  TooManyParametersException       = Class.new(RuntimeError)
  AlreadyCompiledException         = Class.new(RuntimeError)
  AmbiguousRouteException          = Class.new(RuntimeError)
  UnsupportedRequestConditionError = Class.new(RuntimeError)
  AmbiguousVariableException       = Class.new(RuntimeError)

  attr_reader :named_routes, :routes, :root

  def self.override_rack_mapper!
    require File.join('ext', 'rack', 'rack_mapper')
  end

  def initialize(*args, &block)
    if args.first.is_a?(Hash)
      default_app = nil
      options = args.first
    else
      default_app = args.first
      options = args.last
    end

    @options                 = options
    @default_app             = default_app || options && options[:default_app] || proc{|env| ::Rack::Response.new("Not Found", 404).finish }
    @ignore_trailing_slash   = options && options.key?(:ignore_trailing_slash) ? options[:ignore_trailing_slash] : true
    @redirect_trailing_slash = options && options.key?(:redirect_trailing_slash) ? options[:redirect_trailing_slash] : false
    @routes                  = []
    @named_routes            = {}
    @init_block              = block
    reset!
    instance_eval(&block) if block
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
  
  def split(path)
    (path[0] == ?/ ? path[1, path.size] : path).split('/')
  end

  def add(path, options = nil)
    add_route Route.new(self, path.dup).with_options(options)
  end

  def add_route(route)
    @routes << route
    route
  end

  def get(path, options = nil)
    add(path, options).get
  end

  def post(path, options = nil)
    add(path, options).post
  end

  def put(path, options = nil)
    add(path, options).put
  end

  def delete(path, options = nil)
    add(path, options).delete
  end

  def only_get(path, options = nil)
    add(path, options).only_get
  end

  def recognize(env)
    response = @root.find(env.is_a?(Hash) ? Rack::Request.new(env) : env)
  end

  # Generate a URL for a specified route.
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

  # Allow the router to be called via Rake / Middleware.
  def call(env)
    request = Rack::Request.new(env)
    if redirect_trailing_slash? && (request.head? || request.get?) && request.path_info[-1] == ?/
      response = Rack::Response.new
      response.redirect(request.path_info[0, request.path_info.size - 1], 302)
      response.finish
    else
      env['router'] = self
      if response = recognize(request)
        if response.matched? && response.route.dest && response.route.dest.respond_to?(:call)
          process_params(env, response)
          consume_path!(request, response) if response.partial_match?
          return response.route.dest.call(env)
        elsif !response.matched?
          return [response.status, response.headers, []]
        end
      end
      @default_app.call(env)
    end
  end
  
  # Returns a new node
  def node(*args)
    Node.new(self, *args)
  end

  # Returns a new request node
  def request_node(*args)
    RequestNode.new(self, *args)
  end

  def arbitrary_node(*args)
    ArbitraryNode.new(self, *args)
  end

  # Returns a new variable
  def variable(*args)
    Variable.new(self, *args)
  end
  
  # Returns a new glob
  def glob(*args)
    Glob.new(self, *args)
  end

  def clone
    cloned_router = HttpRouter.new(@default_app, @options, &@init_block)
    @routes.each do |route|
      new_route = route.clone
      new_route.instance_variable_set(:@router, cloned_router)
    end
    cloned_router
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
