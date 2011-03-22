class HttpRouter
  class Node
    autoload :Glob,          'http_router/node/glob'
    autoload :Variable,      'http_router/node/variable'
    autoload :Regex,         'http_router/node/regex'
    autoload :SpanningRegex, 'http_router/node/spanning_regex'
    autoload :GlobRegex,     'http_router/node/glob_regex'
    autoload :FreeRegex,     'http_router/node/free_regex'
    autoload :Arbitrary,     'http_router/node/arbitrary'
    autoload :Request,       'http_router/node/request'

    attr_reader :priority, :router

    def initialize(router)
      @router = router
    end

    def [](request)
      destination(request, false)
      unless request.path.empty?
        linear(request)
        lookup(request)
        variable(request)
        glob(request)
      end
      destination(request)
    end

    def linear(request)
      @linear && @linear.each{|n| n[request]}
    end

    def lookup(request)
      if @lookup && @lookup[request.path.first]
        request = request.clone
        @lookup[request.path.shift][request]
      end
    end

    def variable(request)
      @variable && @variable[request]
    end

    def glob(request)
      @glob && @glob[request]
    end

    def request(request)
      @request && @request[request]
    end

    def arbitrary(request)
      @arbitrary && @arbitrary.each{|n| n[request]}
    end

    def unescape(val)
      val.to_s.gsub(/((?:%[0-9a-fA-F]{2})+)/n){ [$1.delete('%')].pack('H*') }
    end

    def destination(request_obj, match_partially = true)
      request(request_obj)
      arbitrary(request_obj)
      if match_partially or request_obj.path.empty?
        @destination && @destination.each do |d|
          if request_obj.path.empty? or d.route.match_partially? or (@router.ignore_trailing_slash? and request_obj.path.size == 1 and request_obj.path.last == '')
            if request_obj.perform_call
              env = request_obj.rack_request.dup.env
              env['router.params'] ||= {}
              env['router.params'].merge!(d.hashify_params(request_obj.params))
              matched = if d.route.match_partially?
                env['PATH_INFO'] = "/#{request_obj.path.join('/')}"
                env['SCRIPT_NAME'] += request_obj.rack_request.path_info[0, request_obj.rack_request.path_info.size - env['PATH_INFO'].size]
              else
                env["PATH_INFO"] = ''
                env["SCRIPT_NAME"] += request_obj.rack_request.path_info
              end
              throw :success, d.route.dest.call(env)
            else
              throw :success, Response.new(request_obj, d)
            end
          end
        end
      end
    end

    def add_variable
      @variable ||= Variable.new(@router)
    end

    def add_glob
      @glob ||= Glob.new(@router)
    end

    def add_request(opts)
      @request ||= Request.new(@router)
      next_requests = [@request]
      Request.request_methods.each do |method|
        method_index = Request.request_methods.index(method)
        next_requests.map! do |next_request|
          if opts[method].nil? && next_request.request_method.nil?
            next_request
          else
            next_request_index = next_request.request_method && Request.request_methods.index(next_request.request_method)
            rank = next_request_index ? method_index <=> next_request_index : 0
            case rank
            when 0
              next_request.request_method = method
              (opts[method].nil? ? [nil] : Array(opts[method])).map do |request_matcher|
                case request_matcher
                when nil
                  next_request.add_catchall
                when String
                  next_request.add_lookup(request_matcher)
                when Regexp
                  next_request.add_linear(request_matcher)
                end
              end
            when -1
              next_request
            when 1
              next_request.transform_to(method)
            end
          end
        end
        next_requests.flatten!
      end
      next_requests
    end

    def add_arbitrary(blk, allow_partial, param_names)
      @arbitrary ||= []
      @arbitrary << Arbitrary.new(@router, allow_partial, blk, param_names)
      @arbitrary.last
    end

    def add_match(regexp, matching_indicies = [0], priority = 0, splitting_indicies = nil)
      add_prioritized_match(Regex.new(@router, regexp, matching_indicies, priority, splitting_indicies))
    end

    def add_spanning_match(regexp, matching_indicies = [0], priority = 0, splitting_indicies = nil)
      add_prioritized_match(SpanningRegex.new(@router, regexp, matching_indicies, priority, splitting_indicies))
    end

    def add_prioritized_match(match)
      @linear ||= []
      if match.priority != 0
        @linear.each_with_index { |n, i|
          if match.priority > (n.priority || 0)
            @linear[i, 0] = match
            return @linear[i]
          end
        }
      end
      @linear << match
      @linear.last
    end

    def add_free_match(regexp)
      @linear ||= []
      @linear << FreeRegex.new(@router, regexp)
      @linear.last
    end

    def add_destination(route)
      @destination ||= []
      @destination << route
    end

    def add_lookup(part)
      @lookup ||= {}
      @lookup[part] ||= Node.new(@router)
    end

    def join_whole_path(request)
      request.path.join('/')
    end

  end
end