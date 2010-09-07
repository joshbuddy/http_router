class HttpRouter
  class Node
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
          @catchall ||= router.node
          @catchall.variable = val
          @catchall
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
          current_node = (current_node.catchall ||= router.request_node)
        end
        [current_node]
      else
        [self]
      end
    end
 
    def add_to_linear(val)
      create_linear
      if @linear.assoc(val)
        @linear.assoc(val).last
      else
        new_node = router.node
        @linear << [val, new_node]
        new_node
      end
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
    
    protected
    
    attr_reader :router

    def transplant_value
      if @value
        target_node = @request_node
        while target_node.request_method
          target_node = (target_node.catchall ||= router.request_node)
        end
        target_node.value = @value
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
        elsif current_nodes.first.is_a?(RequestNode) && !current_nodes.first.request_method.nil?
          current_nodes.map!{|n| n.catchall ||= router.request_node}
        end
      end
      transplant_value
      current_nodes
    end

    def escape_val(val)
      val.is_a?(Array) ? val.each{|v| HttpRouter.uri_unescape!(v)} : HttpRouter.uri_unescape!(val)
      val
    end

    def find_on_parts(request, parts, params)
      if parts and !parts.empty?
        if potential = potential_match(request, parts, params)
          return potential
        end
        if @linear && !@linear.empty?
          response = nil
          dupped_parts = nil
          dupped_params = nil
          next_node = @linear.find do |(tester, node)|
            if tester.respond_to?(:matches?) and match = tester.matches?(parts)
              dupped_parts = parts.dup
              dupped_params = params.dup
              dupped_params << escape_val(tester.consume(match, dupped_parts))
              parts.replace(dupped_parts) if response = node.find_on_parts(request, dupped_parts, dupped_params)
            elsif tester.respond_to?(:match) and match = tester.match(parts.whole_path) and match.begin(0) == 0
              dupped_parts = router.split(parts.whole_path[match[0].size, parts.whole_path.size])
              dupped_params = params.dup
              parts.replace(dupped_parts) if response = node.find_on_parts(request, dupped_parts, dupped_params)
            else
              nil
            end
          end
          if response
            params.replace(dupped_params)
            return response
          end
        end
        if match = @lookup && @lookup[parts.first]
          part = parts.shift
          if match = match.find_on_parts(request, parts, params)
            return match
          else
            parts.unshift(part)
          end
        end
        if @catchall
          params << escape_val(@catchall.variable.consume(nil, parts))
          return @catchall.find_on_parts(request, parts, params)
        end
      end
      request_node and request_node.find_on_request_methods(request) or resolve_node(request)
    end

    def create_linear
      @linear ||= []
    end

    def create_lookup
      @lookup ||= {}
    end
    
    protected
      def resolve_node(request)
        if arbitrary_node
          arbitrary_node.find_on_arbitrary(request)
        elsif @value
          self
        else
          nil
        end
      end
    
      def potential_match(request, parts, params)
        parts.size == 1 and parts.first == '' and potential = find_on_parts(request, nil, params) and (router.ignore_trailing_slash? or (potential.value and potential.value.route.trailing_slash_ignore?)) and parts.shift ? potential : nil
      end
  end

  class ArbitraryNode < Node
    def find_on_arbitrary(request)
      next_node = @linear && !@linear.empty? && @linear.find { |(procs, node)| procs.all?{|p| p.call(request)} }
      next_node && next_node.last || @catchall
    end
  end
  
  class RequestNode < Node
    RequestMethods = [:request_method, :host, :port, :scheme, :user_agent, :ip, :fullpath, :query_string].freeze
    attr_accessor :request_method
    def find_on_request_methods(request)    
      next_node = if @request_method
        request_value = request.send(request_method)
        linear_node(request, request_value) or lookup_node(request, request_value) or catchall_node(request)
      end
      next_node or resolve_node(request)
    end
    private
      def linear_node(request, request_value)
        if @linear && !@linear.empty?
          node = @linear.find { |(regexp, node)| regexp === request_value }
          node.last.find_on_request_methods(request) if node
        end
      end
      def lookup_node(request, request_value)
        @lookup[request_value].find_on_request_methods(request) if @lookup and @lookup[request_value]
      end
      def catchall_node(request)
        @catchall.find_on_request_methods(request) if @catchall
      end
  end
  
end
