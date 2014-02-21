require 'set'
require 'rack'
require 'uri'
require 'cgi'
require 'url_mount'
require 'http_router/node'
require 'http_router/request'
require 'http_router/response'
require 'http_router/route'
require 'http_router/generator'
require 'http_router/route_helper'
require 'http_router/generation_helper'
require 'http_router/regex_route_generation'
require 'http_router/util'

class HttpRouter
  # Raised when a url is not able to be generated for the given parameters
  InvalidRouteException       = Class.new(RuntimeError)
  # Raised when a Route is not able to be generated due to a missing parameter.
  MissingParameterException   = Class.new(RuntimeError)
  # Raised an invalid request value is used
  InvalidRequestValueError    = Class.new(RuntimeError)
  # Raised when there are extra parameters passed in to #url
  TooManyParametersException  = Class.new(RuntimeError)
  # Raised when there are left over options
  LeftOverOptions             = Class.new(RuntimeError)
  # Raised when there are duplicate param names specified in a Path
  AmbiguousVariableException  = Class.new(RuntimeError)

  RecognizeResponse           = Struct.new(:matches, :acceptable_methods)

  attr_reader :root, :routes, :named_routes, :nodes
  attr_writer :route_class
  attr_accessor :default_app, :url_mount, :default_host, :default_port, :default_scheme

  # Creates a new HttpRouter.
  # Can be called with either <tt>HttpRouter.new(proc{|env| ... }, { .. options .. })</tt> or with the first argument omitted.
  # If there is a proc first, then it's used as the default app in the case of a non-match.
  # Supported options are
  # * :default_app -- Default application used if there is a non-match on #call. Defaults to 404 generator.
  # * :ignore_trailing_slash -- Ignore a trailing / when attempting to match. Defaults to +true+.
  # * :redirect_trailing_slash -- On trailing /, redirect to the same path without the /. Defaults to +false+.
  def initialize(*args, &blk)
    default_app, options     = args.first.is_a?(Hash) ? [nil, args.first] : [args.first, args[1]]
    @options                 = options
    @default_app             = default_app || options && options[:default_app] || proc{|env| ::Rack::Response.new("Not Found", 404, {'X-Cascade' => 'pass'}).finish }
    @ignore_trailing_slash   = options && options.key?(:ignore_trailing_slash) ? options[:ignore_trailing_slash] : true
    @redirect_trailing_slash = options && options.key?(:redirect_trailing_slash) ? options[:redirect_trailing_slash] : false
    @route_class             = Route
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
    uncompile
    opts = args.last.is_a?(Hash) ? args.pop : nil
    path = args.first
    route = route_class.new
    add_route route
    route.path = path if path
    route.process_opts(opts) if opts
    route.to(app) if app
    route
  end

  def add_route(route)
    @routes << route
    @named_routes[route.name] << route if route.name
    route.router = self
  end

  # Extends the route class with custom features.
  #
  # Example:
  #   router = HttpRouter.new { extend_route { attr_accessor :controller } }
  #   router.add('/foo', :controller => :foo).to{|env| [200, {}, ['foo!']]}
  #   matches, other_methods = router.recognize(Rack::MockRequest.env_for('/foo'))
  #   matches.first.route.controller
  #   # ==> :foo
  def extend_route(&blk)
    @route_class = Class.new(Route) if @route_class == Route
    @route_class.class_eval(&blk)
    @extended_route_class = nil
  end

  def route_class
    @extended_route_class ||= begin
      @route_class.send(:include, RouteHelper)
      @route_class.send(:include, GenerationHelper)
      @route_class
    end
  end

  # Creates helper methods for each supported HTTP verb, except GET, which is
  # a special case that accepts both GET and HEAD requests.
  Route::VALID_HTTP_VERBS_WITHOUT_GET.each do |request_method|
    request_method_symbol = request_method.downcase.to_sym
    define_method(request_method_symbol) do |path, opts = {}, &app|
      add_with_request_method(path, request_method_symbol, opts, &app)
    end
  end

  # Adds a path that only responds to the request method +GET+.
  #
  # Returns the route object.
  def get(path, opts = {}, &app); add_with_request_method(path, [:get, :head], opts, &app); end

  # Performs recoginition without actually calling the application and returns an array of all
  # matching routes or nil if no match was found.
  def recognize(env, &callback)
    if callback
      request = call(env, &callback)
      [request.called?, request.acceptable_methods]
    else
      matches = []
      callback ||= Proc.new {|match| matches << match}
      request = call(env, &callback)
      [matches.empty? ? nil : matches, request.acceptable_methods]
    end
  end

  # Rack compatible #call. If matching route is found, and +dest+ value responds to #call, processing will pass to the matched route. Otherwise,
  # the default application will be called. The router will be available in the env under the key <tt>router</tt>. And parameters matched will
  # be available under the key <tt>router.params</tt>.
  def call(env, &callback)
    compile
    call(env, &callback)
  end
  alias_method :compiling_call, :call

  # Resets the router to a clean state.
  def reset!
    uncompile
    @routes, @named_routes, @root = [], Hash.new{|h,k| h[k] = []}, Node::Root.new(self)
    @default_app = Proc.new{ |env| ::Rack::Response.new("Your request couldn't be found", 404).finish }
    @default_host, @default_port, @default_scheme = 'localhost', 80, 'http'
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
  #   router.add('/:foo.:format', :name => :test).to{|env| [200, {}, []]}
  #   router.path(:test, 123, 'html')
  #   # ==> "/123.html"
  #   router.path(:test, 123, :format => 'html')
  #   # ==> "/123.html"
  #   router.path(:test, :foo => 123, :format => 'html')
  #   # ==> "/123.html"
  #   router.path(:test, :foo => 123, :format => 'html', :fun => 'inthesun')
  #   # ==> "/123.html?fun=inthesun"
  def url(route, *args)
    compile
    url(route, *args)
  end
  alias_method :compiling_url, :url

  def url_ns(route, *args)
    compile
    url_ns(route, *args)
  end
  alias_method :compiling_url_ns, :url_ns

  def path(route, *args)
    compile
    path(route, *args)
  end
  alias_method :compiling_path, :path

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
      new_route = route.create_clone(cloned_router)
      cloned_router.add_route(new_route)
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

  def no_response(request, env)
    request.acceptable_methods.empty? ?
      @default_app.call(env) : [405, {'Allow' => request.acceptable_methods.sort.join(", ")}, []]
  end

  def to_s
    compile
    "#<HttpRouter:0x#{object_id.to_s(16)} number of routes (#{routes.size}) ignore_trailing_slash? (#{ignore_trailing_slash?}) redirect_trailing_slash? (#{redirect_trailing_slash?})>"
  end

  def inspect
    head = to_s
    "#{to_s}\n#{'=' * head.size}\n#{@root.inspect}"
  end

  def uncompile
    return unless @compiled
    instance_eval "undef :path;   alias :path   :compiling_path
                   undef :url;    alias :url    :compiling_url
                   undef :url_ns; alias :url_ns :compiling_url_ns
                   undef :call;   alias :call   :compiling_call", __FILE__, __LINE__
    @root.uncompile
    @compiled = false
  end

  def raw_url(route, *args)
    case route
    when Symbol then @named_routes.key?(route) && @named_routes[route].each{|r| url = r.url(*args); return url if url}
    when Route  then return route.url(*args)
    end
    raise(InvalidRouteException.new "No route (url) could be generated for #{route.inspect}")
  end

  def raw_url_ns(route, *args)
    case route
    when Symbol then @named_routes.key?(route) && @named_routes[route].each{|r| url = r.url_ns(*args); return url if url}
    when Route  then return route.url_ns(*args)
    end
    raise(InvalidRouteException.new "No route (url_ns) could be generated for #{route.inspect}")
  end

  def raw_path(route, *args)
    case route
    when Symbol then @named_routes.key?(route) && @named_routes[route].each{|r| path = r.path(*args); return path if path}
    when Route  then return route.path(*args)
    end
    raise(InvalidRouteException.new "No route (path) could be generated for #{route.inspect}")
  end

  def raw_call(env, &blk)
    rack_request = ::Rack::Request.new(env)
    request = Request.new(rack_request.path_info, rack_request)
    if blk
      @root.call(request, &blk)
      request
    else
      @root.call(request) or no_response(request, env)
    end
  end

  private
  def compile
    return if @compiled
    @root.compile(@routes)
    @named_routes.each do |_, routes|
      routes.sort!{|r1, r2| r2.max_param_count <=> r1.max_param_count }
    end

    instance_eval "undef :path;   alias :path   :raw_path
                   undef :url;    alias :url    :raw_url
                   undef :url_ns; alias :url_ns :raw_url_ns
                   undef :call;   alias :call   :raw_call", __FILE__, __LINE__
    @compiled = true
  end

  def add_with_request_method(path, method, opts = {}, &app)
    opts[:request_method] = method
    route = add(path, opts)
    route.to(app) if app
    route
  end
end
