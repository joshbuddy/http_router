$LOAD_PATH << File.dirname(__FILE__)
require 'rack'
require 'rack/uri_escape'

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
  RoutingError                = Struct.new(:status, :headers)

  attr_reader :routes

  def initialize(options = nil)
    reset!
    @default_app = options && options[:default_app] || proc{|env| ::Rack::Response.new("Not Found", 404).finish }
    @ignore_trailing_slash   = options && options.key?(:ignore_trailing_slash) ? options[:ignore_trailing_slash] : true
    @redirect_trailing_slash = options && options.key?(:redirect_trailing_slash) ? options[:redirect_trailing_slash] : false
  end

  def ignore_trailing_slash?
    @ignore_trailing_slash
  end

  def redirect_trailing_slash?
    @redirect_trailing_slash
  end

  def reset!
    @root = Root.new(self)
    @routes = {}
  end

  def default(app)
    @default_app = app
  end
  
  def split(path, with_delimiter = false)
    path.slice!(0) if path[0] == ?/
    with_delimiter ? path.split('(/)') : path.split('/')
  end

  def add(path, options = nil)
    path = path.dup
    partially_match       = extract_partial_match(path)
    trailing_slash_ignore = extract_trailing_slash(path)
    paths                 = compile(path, options)
    
    route = Route.new(self, options && options[:default_values])
    route.trailing_slash_ignore = trailing_slash_ignore
    route.partially_match = partially_match
    paths.each_with_index do |path, i|
      current_node = @root.add_path(path)
      working_set = current_node.add_request_methods(options)
      working_set.each do |current_node|
        current_node.value = path
        path.route = route
        route.paths << current_node.value
      end
    end
    route
  end

  def get(path, options = {})
    options[:conditions] ||= {}
    options[:conditions][:request_method] = ['HEAD', 'GET'] #TODO, this should be able to take an array
    add(path, options)
  end

  def post(path, options = {})
    options[:conditions] ||= {}
    options[:conditions][:request_method] = 'POST'
    add(path, options)
  end

  def put(path, options = {})
    options[:conditions] ||= {}
    options[:conditions][:request_method] = 'PUT'
    add(path, options)
  end

  def delete(path, options = {})
    options[:conditions] ||= {}
    options[:conditions][:request_method] = 'DELETE'
    add(path, options)
  end

  def only_get(path, options = {})
    options[:conditions] ||= {}
    options[:conditions][:request_method] = "GET"
    add(path, options)
  end

  def extract_partial_match(path)
    if path[-1] == ?*
      path.slice!(-1)
      true
    else
      false
    end
  end

  def extract_trailing_slash(path)
    if path[-2, 2] == '/?'
      path.slice!(-2, 2)
      true
    else
      false
    end
  end

  def extract_extension(path)
    if match = path.match(/^(.*)(\.:([a-zA-Z_]+))$/)
      path.replace(match[1])
      Variable.new(self, match[3].to_sym)
    elsif match = path.match(/^(.*)(\.([a-zA-Z_]+))$/)
      path.replace(match[1])
      match[3]
    end
  end

  def compile(path, options)
    start_index = 0
    end_index = 1

    paths = [""]
    chars = path.split('')

    chars.each do |c|
      case c
        when '('
          # over current working set, double paths
          (start_index...end_index).each do |path_index|
            paths << paths[path_index].dup
          end
          start_index = end_index
          end_index = paths.size
        when ')'
          start_index -= end_index - start_index
        else
          (start_index...end_index).each do |path_index|
            paths[path_index] << c
          end
      end
    end
    
    variables = {}
    paths.map do |path|
      original_path = path.dup
      extension = extract_extension(path)
      new_path = split(path).map do |part|
        case part[0]
        when ?:
          v_name = part[1, part.size].to_sym
          variables[v_name] ||= Variable.new(self, v_name, options && options[:matches_with] && options && options[:matches_with][v_name])
        when ?*
          v_name = part[1, part.size].to_sym
          variables[v_name] ||= Glob.new(self, v_name, options && options[:matches_with] && options && options[:matches_with][v_name])
        else
          part_segments = part.split(/(:[a-zA-Z_]+)/)
          if part_segments.size > 1
            index = 0
            part_segments.map do |seg|
              new_seg = if seg[0] == ?:
                next_index = index + 1
                scan_regex = if next_index == part_segments.size
                  /^[^\/]+/
                else
                  /^.*?(?=#{Regexp.quote(part_segments[next_index])})/
                end
                v_name = seg[1, seg.size].to_sym
                variables[v_name] ||= Variable.new(self, v_name, scan_regex)
              else
                /^#{Regexp.quote(seg)}/
              end
              index += 1
              new_seg
            end
          else
            part
          end
        end
      end
      new_path.flatten!
      Path.new(original_path, new_path, extension)
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
      if response.is_a?(RoutingError)
        [response.status, response.headers, []]
      elsif response && response.route.dest && response.route.dest.respond_to?(:call)
        process_params(env, response)
        consume_path!(request, response) if response.partial_match?
        #if response.rest
        #  request.env["SCRIPT_NAME"] += request.env["PATH_INFO"][0, -response.rest.size]
        #  request.env["PATH_INFO"] = response.rest || ''
        #end
        response.route.dest.call(env)
      else
        @default_app.call(env)
      end
    end
  end

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

  def recognize(env)
    response = @root.find(env.is_a?(Hash) ? Rack::Request.new(env) : env)
  end

  def url(route, *args)
    case route
      when Symbol
        url(@routes[route], *args)
      when nil
        raise UngeneratableRouteException.new
      else
        route.url(*args)
    end
  end
end
