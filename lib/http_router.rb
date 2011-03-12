require 'set'
require 'rack'
require 'http_router/node'
require 'http_router/request'
require 'http_router/route'
require 'http_router/path'
require 'http_router/regex_route'
require 'http_router/optional_compiler'

class HttpRouter
  
  attr_reader :root, :routes, :known_methods, :named_routes
  attr_accessor :default_app

  UngeneratableRouteException = Class.new(RuntimeError)
  InvalidRouteException = Class.new(RuntimeError)
  MissingParameterException = Class.new(RuntimeError)

  def initialize(&blk)
    reset!
    @named_routes = {}
    @handle_unavailable_route  = Proc.new{ raise UngeneratableRouteException }
    instance_eval(&blk) if blk
  end

  def add(path, opts = {}, &app)
    route = case path
    when Regexp
      RegexRoute.new(self, path, opts)
    else
      Route.new(self, path, opts)
    end
    @routes << route
    route.to(&app) if app
    route
  end
  
  def call(env, perform_call = true)
    rack_request = Rack::Request.new(env)
    request = Request.new(rack_request.path_info, rack_request, perform_call)
    response = catch(:success) {
      @root[request]
    }
    if response || !perform_call
      response
    elsif env['router.request_miss']
      supported_methods = (@known_methods - [env['REQUEST_METHOD']]).select do |m| 
        test_env = env.clone
        test_env['REQUEST_METHOD'] = m
        call(test_env, false).is_a?(Path)
      end
      [405, {'Allow' => supported_methods.sort.join(", ")}, []]
    else
      @default_app.call(env)
    end
  end
  
  def reset!
    @root = Node.new
    @default_app = Proc.new{ |env| Rack::Response.new("Your request couldn't be found", 404).finish }
    @routes = []
    @known_methods = Set.new
  end

  def url(route, *args)
    case route
    when Symbol then url(@named_routes[route], *args)
    when Route  then route.url(*args)
    end
  end

  def self.uri_escape!(s)
    s.to_s.gsub!(/([^:\/?\[\]\-_~\.!\$&'\(\)\*\+,;=@a-zA-Z0-9]+)/n) { "%#{$1.unpack('H2'*$1.size).join('%').upcase}" }
  end

  def append_querystring(uri, params)
    if params && !params.empty?
      uri_size = uri.size
      params.each do |k,v|
        case v
        when Array
          v.each { |v_part| uri << '&' << ::Rack::Utils.escape(k.to_s) << '%5B%5D=' << ::Rack::Utils.escape(v_part.to_s) }
        else
          uri << '&' << ::Rack::Utils.escape(k.to_s) << '=' << ::Rack::Utils.escape(v.to_s)
        end
      end
      uri[uri_size] = ??
    end
    uri
  end
end


