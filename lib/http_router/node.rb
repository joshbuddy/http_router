class HttpRouter
  class Node
    class Response < Struct.new(:path, :param_values)
      attr_reader :params
      def initialize(path, param_values)
        super
        if path.splitting_indexes
          param_values = param_values.dup
          path.splitting_indexes.each{|i| param_values[i] = param_values[i].split(HttpRouter::Parts::SLASH_RX)}
        end
        @params = path.route.default_values ? path.route.default_values.merge(path.hashify_params(param_values)) : path.hashify_params(param_values)
      end
    end

    attr_accessor :value, :variable, :catchall
    attr_reader :linear, :lookup, :request_node, :arbitrary_node

    def initialize(router)
      @router = router
      reset!
    end

    def reset!
      @linear, @lookup, @catchall = nil, nil, nil
    end

    def add(val)
      if val.respond_to?(:matches?)
        if val.matches_with
          add_to_linear(val)
        else
          add_to_catchall(val)
        end
      elsif val.is_a?(Regexp)
        add_to_linear(val)
      else
        create_lookup
        @lookup[val] ||= router.node
      end
    end
    
    def add_to_linear(val)
      create_linear
      n = if @linear.assoc(val)
        @linear.assoc(val).last
      else
        new_node = router.node
        @linear << [val, new_node]
        new_node
      end
      @linear.sort!{|a, b| b.first.priority <=> a.first.priority }
      n
    end
   
    def add_arbitrary(procs)
      target = self
      if procs && !procs.empty?
        @arbitrary_node ||= router.arbitrary_node
        @arbitrary_node.create_linear
        target = router.node
        @arbitrary_node.linear << [procs, target]
        if @value
          @arbitrary_node.catchall = router.node
          @arbitrary_node.catchall.value = @value
          @value = nil
        end
      elsif @arbitrary_node
        target = @arbitrary_node.catchall = router.node
      end
      target
    end
    
    def add_to_catchall(val)
      (@catchall ||= router.node).variable = val
      @catchall
    end
    
    def add_request_methods(request_options)
      raise UnsupportedRequestConditionError if request_options && (request_options.keys & RequestNode::RequestMethods).size != request_options.size
      current_nodes = [self]
      RequestNode::RequestMethods.each do |method|
        if request_options && request_options.key?(method) # so, the request method we care about it ..
          current_nodes = [@request_node ||= router.request_node] if current_nodes == [self]
          for current_node_index in (0...current_nodes.size)
            current_node = current_nodes.at(current_node_index)
            current_node.request_method = method unless current_node.request_method
            case RequestNode::RequestMethods.index(method) <=> RequestNode::RequestMethods.index(current_node.request_method)
            when 0 #use this node
              Array(request_options[method]).each_with_index do |request_value, index|
                if request_value.is_a?(Regexp)
                  new_node = router.request_node
                  current_nodes[index == 0 ? current_node_index : current_nodes.length] = new_node
                  current_node.create_linear
                  current_node.linear << [request_value, new_node]
                else
                  router.request_methods_specified << request_value if method == :request_method
                  current_node.create_lookup
                  current_nodes[index == 0 ? current_node_index : current_nodes.length] = (current_node.lookup[request_value] ||= router.request_node)
                end
              end
            when 1 #this node is farther ahead
              current_nodes[current_node_index] = (current_node.catchall ||= router.request_node)
            when -1 #this method is more important than the current node
              next_node = current_node.dup
              current_node.reset!
              current_node.request_method = method
              current_node.catchall ||= next_node
              redo
            end
          end
          current_nodes.flatten!
        else
          current_nodes.map!{|n| n.is_a?(RequestNode) && n.request_method == method ? (n.catchall ||= router.request_node) : n}
        end
      end
      transplant_value
      current_nodes
    end

    protected
    
    attr_reader :router

    def transplant_value
      if @value && @request_node
        target_node = @request_node
        while target_node.request_method
          target_node = (target_node.catchall ||= router.request_node)
        end
        target_node.value ||= @value
        @value = nil
      end
    end
    
    def escape_val(val)
      val.is_a?(Array) ? val.each{|v| HttpRouter.uri_unescape!(v)} : HttpRouter.uri_unescape!(val)
      val
    end

    def find_on_parts(request, parts, action = :call, params = [])
      if parts and !parts.empty?
        find_on_parts(request, nil, :"#{action}_with_trailing_slash", params) if parts.size == 1 and parts.first == ''
        if @linear
          dupped_parts, dupped_params = nil, nil
          response = @linear.find do |(tester, node)|
            if tester.respond_to?(:matches?) and match = tester.matches?(parts)
              dupped_parts, dupped_params = parts.dup, params.dup
              dupped_params << escape_val(tester.consume(match, dupped_parts))
              node.find_on_parts(request, dupped_parts, action, dupped_params)
            elsif tester.respond_to?(:match) and match = tester.match(parts.whole_path) and match.begin(0) == 0
              dupped_parts, dupped_params = router.split(parts.whole_path[match[0].size, parts.whole_path.size]), params.dup
              node.find_on_parts(request, dupped_parts, action, dupped_params)
            else
              nil
            end
          end
        end
        if match = @lookup && @lookup[parts.first]
          match.find_on_parts(request, parts[1, parts.size - 1], action, params)
        end
        if catchall
          dupped_parts, dupped_params = parts.dup, params.dup
          dupped_params << escape_val(catchall.variable.consume(nil, dupped_parts))
          catchall.find_on_parts(request, dupped_parts, action, dupped_params)
        end
      end
      request_node.find_on_request_methods(request, parts, action, params) if request_node
      arbitrary_node.find_on_arbitrary(request, parts, action, params) if arbitrary_node
      response = process_match(self, parts, params, request, action) if @value
      nil
    end

    def process_match(node, parts, params, request, action)
      env = request.env
      case action
      when :nocall, :nocall_with_trailing_slash
        throw :response, node.value.map{|path| Response.new(path, params)}
      when :call, :call_with_trailing_slash
        node.value.each do |path|
          response_struct = Response.new(path, params)
          previous_params = env['router.params']
          env['router'] = router
          env['router.params'] ||= {}
          env['router.params'].merge!(response_struct.params)
          env['router.response'] = response_struct
          env['SCRIPT_NAME'] ||= ''
          matched = if path.route.partially_match?
            env['PATH_INFO'] = "#{HttpRouter::Parts::SLASH}#{parts && parts.join(HttpRouter::Parts::SLASH)}"
            env['SCRIPT_NAME'] += request.path_info[0, request.path_info.size - env['PATH_INFO'].size]
            true
          elsif (parts and (action == :call_with_trailing_slash) and (router.ignore_trailing_slash? or (parts.size == 1 and parts.first == ''))) or parts.nil? || parts.empty?
            env["PATH_INFO"] = ''
            env["SCRIPT_NAME"] += request.path_info
            true
          else
            false
          end
          if matched
            response = path.route.dest.call(env)
            env['router.last_repsonse'] = response
            if response.first != 404 and response.first != 410
              throw :response, response
            end
          end
        end if node.value
      else
        raise
      end
    end

    protected
      def create_linear
        @linear ||= []
      end

      def create_lookup
        @lookup ||= {}
      end
  end

  class ArbitraryNode < Node
    def find_on_arbitrary(request, parts, action, params)
      next_node = @linear && !@linear.empty? && @linear.find { |(procs, node)| 
        params_hash = node.value ? node.value.first.hashify_params(params) : {}
        procs.all?{|p| p.call(request, params_hash)}
      }
      if next_node
        process_match(next_node.last, parts, params, request, action)
      elsif @catchall
        process_match(@catchall, parts, params, request, action)
      elsif @value
        process_match(self, parts, params, request, action)
      end
    end
  end
  
  class RequestNode < Node
    RequestMethods = [:request_method, :host, :port, :scheme, :user_agent, :ip, :fullpath, :query_string].freeze
    attr_accessor :request_method
    def find_on_request_methods(request, parts, action, params)
      if @request_method
        request_value = request.send(request_method)
        if @linear && !@linear.empty? && match = @linear.find { |(regexp, node)| regexp === request_value }
          match.last.find_on_request_methods(request, parts, action, params)
        end
        @lookup[request_value].find_on_request_methods(request, parts, action, params) if @lookup and @lookup[request_value]
        @catchall.find_on_request_methods(request, parts, action, params) if @catchall
      end
      if @value
        process_match(self, parts, params, request, action)
      elsif arbitrary_node
        arbitrary_node.find_on_arbitrary(request, parts, action, params)
      end
    end
  end
end
