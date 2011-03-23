require 'set'
require 'rack'
require 'http_router/node'
require 'http_router/request'
require 'http_router/response'
require 'http_router/route'
require 'http_router/path'
require 'http_router/regex_route'
require 'http_router/optional_compiler'

class HttpRouter

  attr_reader :root, :routes, :known_methods, :named_routes
  attr_accessor :default_app, :url_mount

  UngeneratableRouteException = Class.new(RuntimeError)
  InvalidRouteException       = Class.new(RuntimeError)
  MissingParameterException   = Class.new(RuntimeError)

  # Creates a new HttpRouter.
  # Can be called with either <tt>HttpRouter.new(proc{|env| ... }, { .. options .. })</tt> or with the first argument omitted.
  # If there is a proc first, then it's used as the default app in the case of a non-match.
  # Supported options are
  # * :default_app -- Default application used if there is a non-match on #call. Defaults to 404 generator.
  # * :ignore_trailing_slash -- Ignore a trailing / when attempting to match. Defaults to +true+.
  # * :redirect_trailing_slash -- On trailing /, redirect to the same path without the /. Defaults to +false+.
  def initialize(*args, &blk)
    default_app, options = args.first.is_a?(Hash) ? [nil, args.first] : [args.first, args[1]]
    @options = options
    @default_app = default_app || options && options[:default_app] || proc{|env| ::Rack::Response.new("Not Found", 404).finish }
    @ignore_trailing_slash = options && options.key?(:ignore_trailing_slash) ? options[:ignore_trailing_slash] : true
    @redirect_trailing_slash = options && options.key?(:redirect_trailing_slash) ? options[:redirect_trailing_slash] : false
    reset!
    instance_eval(&blk) if blk
  end

  def add(path, opts = {}, &app)
    route = case path
    when Regexp
      RegexRoute.new(self, path, opts)
    else
      Route.new(self, path, opts)
    end
    add_route(route)
    route.to(app) if app
    route
  end

  def add_route(route)
    @routes << route
  end

  def post(path, opts = {}, &app);   add_with_request_method(path, :post, opts, &app);   end
  def get(path, opts = {}, &app);    add_with_request_method(path, :get, opts, &app);    end
  def head(path, opts = {}, &app);   add_with_request_method(path, :head, opts, &app);   end
  def delete(path, opts = {}, &app); add_with_request_method(path, :delete, opts, &app); end
  def put(path, opts = {}, &app);    add_with_request_method(path, :put, opts, &app);    end

  def recognize(env)
    call(env, false)
  end

  def call(env, perform_call = true)
    rack_request = Rack::Request.new(env)
    if redirect_trailing_slash? && (rack_request.head? || rack_request.get?) && rack_request.path_info[-1] == ?/
      response = ::Rack::Response.new
      response.redirect(request.path_info[0, request.path_info.size - 1], 302)
      response.finish
    else
      request = Request.new(rack_request.path_info, rack_request, perform_call)
      response = catch(:success) { @root[request] }
      if !response
        supported_methods = (@known_methods - [env['REQUEST_METHOD']]).select do |m| 
          test_env = Rack::Request.new(rack_request.env.clone)
          test_env.env['REQUEST_METHOD'] = m
          test_env.env['HTTP_ROUTER_405_TESTING_ACCEPTANCE'] = true
          test_request = Request.new(test_env.path_info, test_env, 405)
          catch(:success) { @root[test_request] }
        end
        supported_methods.empty? ? @default_app.call(env) : [405, {'Allow' => supported_methods.sort.join(", ")}, []]
      elsif response
        response
      else
        @default_app.call(env)
      end
    end
  end

  def reset!
    @root = Node.new(self)
    @default_app = Proc.new{ |env| Rack::Response.new("Your request couldn't be found", 404).finish }
    @routes = []
    @named_routes = {}
    @known_methods = ['GET', "POST", "PUT", "DELETE"]
  end

  def url(route, *args)
    case route
    when Symbol then @named_routes.key?(route) ? @named_routes[route].url(*args) : raise(UngeneratableRouteException)
    when Route  then route.url(*args)
    else raise UngeneratableRouteException
    end
  end

  def ignore_trailing_slash?
    @ignore_trailing_slash
  end

  def redirect_trailing_slash?
    @redirect_trailing_slash
  end

  # Creates a deep-copy of the router.
  def clone(klass = self.class)
    cloned_router = klass.new(@options)
    @routes.each do |route|
      new_route = route.clone(cloned_router)
      cloned_router.add_route(new_route)
      new_route.name(route.named) if route.named
      begin
        new_route.to route.dest.clone
      rescue
        new_route.to route.dest
      end
    end
    cloned_router
  end

  private
  def add_with_request_method(path, method, opts = {}, &app)
    route = add(path, opts).send(method.to_sym)
    route.to(app) if app
    route
  end
end
