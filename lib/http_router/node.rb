class HttpRouter
  class Node
    Response = Struct.new(:path, :param_values, :params)
    attr_accessor :value, :variable, :catchalls
    attr_reader :linear, :lookup, :request_node, :arbitrary_node

    def initialize(router)
      @router = router
      reset!
    end

    def reset!
      @linear, @lookup, @catchalls = nil, nil, nil
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
    
    def add_request_methods(options)
      if !options.empty?
        generate_request_method_tree(options)
      elsif @request_node
        current_node = @request_node
        while current_node.request_method
          current_node = (current_node.catchalls ||= router.request_node)
        end
        [current_node]
      else
        [self]
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
          @arbitrary_node.catchalls = router.node
          @arbitrary_node.catchalls.value = @value
          @value = nil
        end
      elsif @arbitrary_node
        target = @arbitrary_node.catchalls = router.node
      end
      target
    end
    
    def add_to_catchall(val)
      @catchalls ||= []
      node = @catchalls.find{|c| c.variable.matches_with == val.matches_with and c.variable.class == val.class}
      if node
        node
      elsif val.is_a?(Glob)
        @catchalls.push router.node
        @catchalls.last.variable = val
        @catchalls.last
      else
        @catchalls.unshift router.node
        @catchalls.first.variable = val
        @catchalls.first
      end
    end
    
    protected
    
    attr_reader :router

    def transplant_value
      if @value
        target_node = @request_node
        while target_node.request_method
          target_node = (target_node.catchalls ||= router.request_node)
        end
        target_node.value ||= @value
        @value = nil
      end
    end
    
    def generate_request_method_tree(request_options)
      raise UnsupportedRequestConditionError if (request_options.keys & RequestNode::RequestMethods).size != request_options.size
      current_nodes = [self]
      RequestNode::RequestMethods.each do |method|
        if request_options.key?(method) # so, the request method we care about it ..
          if current_nodes == [self]
            current_nodes = [@request_node ||= router.request_node]
          end
          
          for current_node_index in (0...current_nodes.size)
            current_node = current_nodes.at(current_node_index)
            unless current_node.request_method
              current_node.request_method = method
            end
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
              current_nodes[current_node_index] = (current_node.catchalls ||= router.request_node)
            when -1 #this method is more important than the current node
              next_node = current_node.dup
              current_node.reset!
              current_node.request_method = method
              current_node.catchalls ||= next_node
              redo
            end
          end
          current_nodes.flatten!
        elsif current_nodes.first.is_a?(RequestNode) && !current_nodes.first.request_method.nil?
          current_nodes.map!{|n| n.catchalls ||= router.request_node}
        end
      end
      transplant_value
      current_nodes
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
        if @catchalls
          @catchalls.each do |c|
            dupped_parts, dupped_params = parts.dup, params.dup
            dupped_params << escape_val(c.variable.consume(nil, dupped_parts))
            c.find_on_parts(request, dupped_parts, action, dupped_params)
          end
        end
      end
      request_node.find_on_request_methods(request, parts, action, params) if request_node
      arbitrary_node.find_on_arbitrary(request, parts, action, params) if arbitrary_node
      response = process_match(self, parts, params, request, action) if @value
      nil
    end

    def process_match(node, parts, params, request, action)
      env = request.env
      path = node.value
      path.splitting_indexes and path.splitting_indexes.each{|i| params[i] = params[i].split(HttpRouter::Parts::SLASH_RX)}
      params_as_hash = path.route.default_values ? path.route.default_values.merge(path.hashify_params(params)) : path.hashify_params(params)
      response_struct = Response.new(path, params, params_as_hash)
      previous_params = env['router.params']
      env['router'] = router
      env['router.params'] ||= {}
      env['router.params'].merge!(params_as_hash)
      env['router.response'] = response_struct
      env['SCRIPT_NAME'] ||= ''
      matched = if node.value.route.partially_match?
        env['PATH_INFO'] = "#{HttpRouter::Parts::SLASH}#{parts && parts.join(HttpRouter::Parts::SLASH)}"
        env['SCRIPT_NAME'] += request.path_info[0, request.path_info.size - env['PATH_INFO'].size]
        true
      elsif (parts and (action == :call_with_trailing_slash || action == :nocall_with_trailing_slash) and (router.ignore_trailing_slash? or (parts.size == 1 and parts.first == ''))) or parts.nil? || parts.empty?
        env["PATH_INFO"] = ''
        env["SCRIPT_NAME"] += request.path_info
        true
      else
        false
      end
      if matched
        case action
        when :call, :call_with_trailing_slash
          response = path.route.dest.call(env)
          env['router.last_repsonse'] = response
          if response.first != 404 and response.first != 410
            throw :response, response
          end
        when :nocall, :nocall_with_trailing_slash
          throw :response, response_struct
        else
          raise
        end
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
        params_hash = node.value.hashify_params(params) || {}
        procs.all?{|p| p.call(request, params_hash, node.value.route.dest)}
      }
      if next_node
        process_match(next_node.last, parts, params, request, action)
      elsif @catchalls
        process_match(@catchalls, parts, params, request, action)
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
        @catchalls.find_on_request_methods(request, parts, action, params) if @catchalls
      end
      if @value
        process_match(self, parts, params, request, action)
      else
        find_on_parts(request, parts, action, params)
      end
    end
  end
end
