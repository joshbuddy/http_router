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

    attr_reader :priority

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
      if request_obj.path.empty? or (match_partially and request_obj.path.size == 1 and request_obj.path.last == '')
        request(request_obj)
        arbitrary(request_obj)
      end
      @destination && @destination.each do |d| 
        if (d.route.match_partially? && match_partially) or request_obj.path.empty? or (request_obj.path.size == 1 and request_obj.path.last == '')
          if request_obj.perform_call
            env = request_obj.rack_request.dup.env
            env['router.params'] ||= {}
            env['router.params'].merge!(Hash[d.param_names.zip(request_obj.params)])
            matched = if d.route.match_partially?
              env['PATH_INFO'] = "/#{request_obj.path.join('/')}"
              env['SCRIPT_NAME'] += request_obj.rack_request.path_info[0, request_obj.rack_request.path_info.size - env['PATH_INFO'].size]
            else
              env["PATH_INFO"] = ''
              env["SCRIPT_NAME"] += request_obj.rack_request.path_info
            end
            throw :success, d.route.dest.call(env)
          else
            throw :success, d
          end
        end
      end
    end

    def add_variable
      @variable ||= Variable.new
    end

    def add_glob
      @glob ||= Glob.new
    end
  
    def add_request(opts)
      @request ||= Request.new
      next_request = @request
      Request.request_methods.each do |method|
        next_request.request_method = method
        next_request = case opts[method]
        when nil
          next_request.add_catchall
        when String
          next_request.add_lookup(opts[method])
        when Regexp
          next_request.add_linear(opts[method])
        end
      end
      next_request
    end
  
    def add_arbitrary(blk, param_names)
      @arbitrary ||= []
      @arbitrary << Arbitrary.new(blk, param_names)
      @arbitrary.last
    end
  
    def add_match(regexp, matching_indicies = [0], priority = 0)
      @linear ||= []
      if priority != 0
        @linear.each_with_index { |n, i|
          if priority > (n.priority || 0)
            @linear[i, 0] = Regex.new(regexp, matching_indicies, priority)
            return @linear[i]
          end
        }
      end
      @linear << Regex.new(regexp, matching_indicies, priority)
      @linear.last
    end

    def add_spanning_match(regexp, matching_indicies = [0])
      @linear ||= []
      @linear << SpanningRegex.new(regexp, matching_indicies)
      @linear.last
    end
  
    def add_free_match(regexp)
      @linear ||= []
      @linear << FreeRegex.new(regexp)
      @linear.last
    end
  
    def add_destination(route)
      @destination ||= []
      @destination << route
    end
  
    def add_lookup(part)
      @lookup ||= {}
      @lookup[part] ||= Node.new
    end

    def join_whole_path(request)
      request.path.join('/')
    end

  end
end