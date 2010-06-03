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

  # Raised when a Route is not able to be generated.
  UngeneratableRouteException      = Class.new(RuntimeError)
  # Raised when a Route is not able to be generated due to a missing parameter.
  MissingParameterException        = Class.new(RuntimeError)
  # Raised when a Route is not able to be generated due to too many parameters being passed in.
  TooManyParametersException       = Class.new(RuntimeError)
  # Raised when an already inserted Route has more conditions added.
  AlreadyCompiledException         = Class.new(RuntimeError)
  # Raised when an ambiguous Route is added. For example, this will be raised if you attempt to add "/foo(/:bar)(/:baz)".
  AmbiguousRouteException          = Class.new(RuntimeError)
  # Raised when a request condition is added that is not recognized.
  UnsupportedRequestConditionError = Class.new(RuntimeError)
  # Raised when there is a potential conflict of variable names within your Route.
  AmbiguousVariableException       = Class.new(RuntimeError)

  attr_reader :named_routes, :routes, :root

  # Monkey-patches Rack::Builder to use HttpRouter.
  # See examples/rack_mapper.rb
  def self.override_rack_mapper!
    require File.join('ext', 'rack', 'rack_mapper')
  end

  # Creates a new HttpRouter.
  # Can be called with either <tt>HttpRouter.new(proc{|env| ... }, { .. options .. })</tt> or with the first argument omitted.
  # If there is a proc first, then it's used as the default app in the case of a non-match.
  # Supported options are
  # * :default_app -- Default application used if there is a non-match on #call. Defaults to 404 generator.
  # * :ignore_trailing_slash -- Ignore a trailing / when attempting to match. Defaults to +true+.
  # * :redirect_trailing_slash -- On trailing /, redirect to the same path without the /. Defaults to +false+.
  # * :middleware -- On recognition, store the route Response in env['router.response'] and always call the default app. Defaults to +false+.
  def initialize(*args, &block)
    default_app, options = args.first.is_a?(Hash) ? [nil, args.first] : [args.first, args[1]]

    @options                 = options
    @default_app             = default_app || options && options[:default_app] || proc{|env| Rack::Response.new("Not Found", 404).finish }
    @ignore_trailing_slash   = options && options.key?(:ignore_trailing_slash) ? options[:ignore_trailing_slash] : true
    @redirect_trailing_slash = options && options.key?(:redirect_trailing_slash) ? options[:redirect_trailing_slash] : false
    @middleware              = options && options.key?(:middleware) ? options[:middleware] : false
    @routes                  = []
    @named_routes            = {}
    @init_block              = block
    reset!
    if block
      instance_eval(&block)
      @routes.each {|r| r.compile}
    end
  end

  # Ignore trailing slash feature enabled? See #initialize for details.
  def ignore_trailing_slash?
    @ignore_trailing_slash
  end

  # Redirect trailing slash feature enabled? See #initialize for details.
  def redirect_trailing_slash?
    @redirect_trailing_slash
  end

  # Resets the router to a clean state.
  def reset!
    @root = Root.new(self)
    @routes.clear
    @named_routes.clear
  end

  # Assigns the default application.
  def default(app)
    @default_app = app
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
  # The second argument, options, is an optional hash that can modify the route in further ways. See HttpRouter::Route#with_options for details. Typically, you want to add further options to the route by calling additional methods on it. See HttpRouter::Route for further details.
  #
  # Returns the route object.
  def add(path, options = nil)
    add_route Route.new(self, path.dup).with_options(options)
  end

  # Adds a route to be recognized. This must be a HttpRouter::Route object. Returns the route just added.
  def add_route(route)
    @routes << route
    route
  end

  # Adds a path that only responds to the request methods +GET+ and +HEAD+.
  #
  # Returns the route object.
  def get(path, options = nil)
    add(path, options).get
  end

  # Adds a path that only responds to the request method +POST+.
  #
  # Returns the route object.
  def post(path, options = nil)
    add(path, options).post
  end

  # Adds a path that only responds to the request method +PUT+.
  #
  # Returns the route object.
  def put(path, options = nil)
    add(path, options).put
  end

  # Adds a path that only responds to the request method +DELETE+.
  #
  # Returns the route object.
  def delete(path, options = nil)
    add(path, options).delete
  end

  # Adds a path that only responds to the request method +GET+.
  #
  # Returns the route object.
  def only_get(path, options = nil)
    add(path, options).only_get
  end

  # Returns the HttpRouter::Response object if the env is matched, otherwise, returns +nil+.
  def recognize(env)
    response = @root.find(env.is_a?(Hash) ? Rack::Request.new(env) : env)
  end

  # Generate a URL for a specified route. This will accept a list of variable values plus any other variable names named as a hash.
  # This first value must be either the Route object or the name of the route.
  # 
  # Example:
  #   router = HttpRouter.new
  #   router.add('/:foo.:format).name(:test).compile
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
      when Symbol
        url(@named_routes[route], *args)
      when nil
        raise UngeneratableRouteException.new
      else
        route.url(*args)
    end
  end

  # Rack compatible #call. If matching route is found, and +dest+ value responds to #call, processing will pass to the matched route. Otherwise, 
  # the default application will be called. The router will be available in the env under the key <tt>router</tt>. And parameters matched will
  # be available under the key <tt>router.params</tt>. The HttpRouter::Response object will be available under the key <tt>router.response</tt> if
  # a response is available.
  def call(env)
    request = Rack::Request.new(env)
    if redirect_trailing_slash? && (request.head? || request.get?) && request.path_info[-1] == ?/
      response = Rack::Response.new
      response.redirect(request.path_info[0, request.path_info.size - 1], 302)
      response.finish
    else
      env['router'] = self
      if response = recognize(request) and !@middleware
        if response.matched? && response.route.dest && response.route.dest.respond_to?(:call)
          process_params(env, response)
          consume_path!(request, response) if response.partial_match?
          return response.route.dest.call(env)
        elsif !response.matched?
          return [response.status, response.headers, []]
        end
      end
      env['router.response'] = response
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

  # Creates a deep-copy of the router.
  def clone
    cloned_router = HttpRouter.new(@default_app, @options, &@init_block)
    @routes.each do |route|
      new_route = route.clone
      new_route.instance_variable_set(:@router, cloned_router)
    end
    cloned_router
  end

  def split(path)
    (path[0] == ?/ ? path[1, path.size] : path).split('/')
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
