require 'set'
require 'rack'
require 'uri'
require 'cgi'
require 'url_mount'
require 'http_router/node'
require 'http_router/request'
require 'http_router/response'
require 'http_router/route'
require 'http_router/rack'
require 'http_router/regex_route'
require 'http_router/util'

class HttpRouter

  attr_reader :root, :routes, :known_methods, :named_routes, :nodes
  attr_accessor :default_app, :url_mount

  # Raised when a url is not able to be generated for the given parameters
  InvalidRouteException       = Class.new(RuntimeError)
  # Raised when a Route is not able to be generated due to a missing parameter.
  MissingParameterException   = Class.new(RuntimeError)
  # Raised when a Route is compiled twice
  DoubleCompileError          = Class.new(RuntimeError)
  # Raised an invalid request value is used
  InvalidRequestValueError    = Class.new(RuntimeError)
  # Raised when there are extra parameters passed in to #url
  TooManyParametersException  = Class.new(RuntimeError)

  # Creates a new HttpRouter.
  # Can be called with either <tt>HttpRouter.new(proc{|env| ... }, { .. options .. })</tt> or with the first argument omitted.
  # If there is a proc first, then it's used as the default app in the case of a non-match.
  # Supported options are
  # * :default_app -- Default application used if there is a non-match on #call. Defaults to 404 generator.
  # * :ignore_trailing_slash -- Ignore a trailing / when attempting to match. Defaults to +true+.
  # * :redirect_trailing_slash -- On trailing /, redirect to the same path without the /. Defaults to +false+.
  # * :known_methods -- Array of http methods tested for 405s.
  def initialize(*args, &blk)
    default_app, options     = args.first.is_a?(Hash) ? [nil, args.first] : [args.first, args[1]]
    @options = options
    @default_app             = default_app || options && options[:default_app] || proc{|env| ::Rack::Response.new("Not Found", 404, {'X-Cascade' => 'pass'}).finish }
    @ignore_trailing_slash   = options && options.key?(:ignore_trailing_slash) ? options[:ignore_trailing_slash] : true
    @redirect_trailing_slash = options && options.key?(:redirect_trailing_slash) ? options[:redirect_trailing_slash] : false
    @known_methods           = Set.new(options && options[:known_methods] || [])
    reset!
    instance_eval(&blk) if blk
  end

  # Adds a path to be recognized.
  #
  # To assign a part of the path to a specific variable, use :variable_name within the route.
  # For example, <tt>add('/path/:id')</tt> would match <tt>/path/test</tt>, with the variable <tt>:id</tt> having the value <tt>"test"</tt>.
  #
  # You can receive mulitple parts into a single variable by using the glob syntax.
  # For example, <tt>add('/path/*id')</tt> would match <tt>/path/123/456/789</tt>, with the variable <tt>:id</tt> having the value <tt>["123", "456", "789"]</tt>.
  #
  # As well, paths can end with two optional parts, <tt>*</tt> and <tt>/?</tt>. If it ends with a <tt>*</tt>, it will match partially, returning the part of the path unmatched in the PATH_INFO value of the env. The part matched to will be returned in the SCRIPT_NAME. If it ends with <tt>/?</tt>, then a trailing / on the path will be optionally matched for that specific route. As trailing /'s are ignored by default, you probably don't actually want to use this option that frequently.
  #
  # Routes can also contain optional parts. There are surrounded with <tt>( )</tt>'s. If you need to match on a bracket in the route itself, you can escape the parentheses with a backslash.
  #
  # As well, options can be passed in that modify the route in further ways. See HttpRouter::Route#with_options for details. Typically, you want to add further options to the route by calling additional methods on it. See HttpRouter::Route for further details.
  #
  # Returns the route object.
  def add(*args, &app)
    opts = args.last.is_a?(Hash) ? args.pop : {}
    path = args.first
    route = add_route((Regexp === path ? RegexRoute : Route).new(self, path, opts))
    route.to(app) if app
    route
  end

  def add_route(route)
    @routes << route
    route
  end

  # Adds a path that only responds to the request method +GET+.
  #
  # Returns the route object.
  def get(path, opts = {}, &app); add_with_request_method(path, :get, opts, &app); end

  # Adds a path that only responds to the request method +POST+.
  #
  # Returns the route object.
  def post(path, opts = {}, &app); add_with_request_method(path, :post, opts, &app); end

  # Adds a path that only responds to the request method +HEAD+.
  #
  # Returns the route object.
  def head(path, opts = {}, &app); add_with_request_method(path, :head, opts, &app); end

  # Adds a path that only responds to the request method +DELETE+.
  #
  # Returns the route object.
  def delete(path, opts = {}, &app); add_with_request_method(path, :delete, opts, &app); end

  # Adds a path that only responds to the request method +PUT+.
  #
  # Returns the route object.
  def put(path, opts = {}, &app); add_with_request_method(path, :put, opts, &app); end

  # Adds a path that only responds to the request method +OPTIONS+.
  #
  # Returns the route object.
  def options(path, opts = {}, &app); add_with_request_method(path, :options, opts, &app); end

  # Performs recoginition without actually calling the application and returns an array of all
  # matching routes or nil if no match was found.
  def recognize(env)
    call(env, false)
  end

  # Rack compatible #call. If matching route is found, and +dest+ value responds to #call, processing will pass to the matched route. Otherwise,
  # the default application will be called. The router will be available in the env under the key <tt>router</tt>. And parameters matched will
  # be available under the key <tt>router.params</tt>.
  def call(env, perform_call = true)
    rack_request = ::Rack::Request.new(env)
    request = Request.new(rack_request.path_info, rack_request, perform_call)
    response = catch(:success) { @root[request] }
    if perform_call
      response or no_response(env)
    else
      request.matches.empty? ? nil : request.matches
    end
  end

  # Resets the router to a clean state.
  def reset!
    @routes, @named_routes, @root = [], Hash.new{|h,k| h[k] = []}, Node::Root.new(self)
    @default_app = Proc.new{ |env| ::Rack::Response.new("Your request couldn't be found", 404).finish }
  end

  # Assigns the default application.
  def default(app)
    @default_app = app
  end

  # Generate a URL for a specified route. This will accept a list of variable values plus any other variable names named as a hash.
  # This first value must be either the Route object or the name of the route.
  #
  # Example:
  #   router = HttpRouter.new
  #   router.add('/:foo.:format').name(:test).to{|env| [200, {}, []]}
  #   router.url(:test, 123, 'html')
  #   # ==> "/123.html"
  #   router.url(:test, 123, :format => 'html')
  #   # ==> "/123.html"
  #   router.url(:test, :foo => 123, :format => 'html')
  #   # ==> "/123.html"
  #   router.url(:test, :foo => 123, :format => 'html', :fun => 'inthesun')
  #   # ==> "/123.html?fun=inthesun"
  def url(route, *args)
    case route
    when Symbol then @named_routes.key?(route) && @named_routes[route].each{|r| url = r.url(*args); return url if url}
    when Route  then return route.url(*args)
    end
    raise(InvalidRouteException)
  end

  # This method is invoked when a Path object gets called with an env. Override it to implement custom path processing.
  def process_destination_path(path, env)
    path.route.dest.call(env)
  end

  # This method defines what sort of responses are considered "passes", and thus, route processing will continue. Override
  # it to implement custom passing.
  def pass_on_response(response)
    response[1]['X-Cascade'] == 'pass'
  end

  # Ignore trailing slash feature enabled? See #initialize for details.
  def ignore_trailing_slash?
    @ignore_trailing_slash
  end

  # Redirect trailing slash feature enabled? See #initialize for details.
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

  def rewrite_partial_path_info(env, request)
    env['PATH_INFO'] = "/#{request.path.join('/')}"
    env['SCRIPT_NAME'] += request.rack_request.path_info[0, request.rack_request.path_info.size - env['PATH_INFO'].size]
  end

  def rewrite_path_info(env, request)
    env['SCRIPT_NAME'] += request.rack_request.path_info
    env['PATH_INFO'] = ''
  end

  def no_response(env)
    supported_methods = @known_methods.select do |m|
      next if m == env['REQUEST_METHOD']
      test_env = ::Rack::Request.new(env.clone)
      test_env.env['REQUEST_METHOD'] = m
      test_env.env['_HTTP_ROUTER_405_TESTING_ACCEPTANCE'] = true
      test_request = Request.new(test_env.path_info, test_env, 405)
      @root[test_request]
      !test_request.matches.empty?
    end
    supported_methods.empty? ? @default_app.call(env) : [405, {'Allow' => supported_methods.sort.join(", ")}, []]
  end

  def to_s
    "#<HttpRouter:0x#{object_id.to_s(16)} number of routes (#{routes.size}) ignore_trailing_slash? (#{ignore_trailing_slash?}) redirect_trailing_slash? (#{redirect_trailing_slash?}) known_methods (#{known_methods.to_a.join(', ')})>"
  end

  def inspect
    head = to_s
    "#{to_s}\n#{'=' * head.size}\n#{@root.inspect}"
  end

  private
  def add_with_request_method(path, method, opts = {}, &app)
    route = add(path, opts).send(method.to_sym)
    route.to(app) if app
    route
  end
end
