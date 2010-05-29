class HttpRouter
  class Node
    attr_accessor :value, :variable, :catchall
    attr_reader :linear, :lookup, :request_node, :extension_node

    def initialize(base)
      @router = base
      reset!
    end

    def reset!
      @linear = nil
      @lookup = nil
      @catchall = nil
    end

    def add(val)
      if val.is_a?(Variable)
        if val.matches_with
          new_node = router.node
          create_linear
          @linear << [val, new_node]
          new_node
        else
          @catchall ||= router.node
          @catchall.variable = val
          @catchall
        end
      elsif val.is_a?(Regexp)
        create_linear
        @linear << [val, router.node]
        @linear.last.last
      else
        create_lookup
        @lookup[val] ||= router.node
      end
    end
    
    def add_extension(ext)
      @extension_node ||= router.node
      @extension_node.add(ext)
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
      raise(UnsupportedRequestConditionError.new) if (request_options.keys & RequestNode::RequestMethods).size != request_options.size
      current_nodes = [self]
      RequestNode::RequestMethods.each do |method|
        if request_options.key?(method) # so, the request method we care about it ..
          if current_nodes == [self]
            current_nodes = [@request_node ||= router.request_node]
          end
          
          for current_node_index in (0...current_nodes.size)
            current_node = current_nodes.at(current_node_index)
            if request_options.key?(method)  #we care about the method
              unless current_node.request_method
                current_node.request_method = method
              end
              case RequestNode::RequestMethods.index(method) <=> RequestNode::RequestMethods.index(current_node.request_method)
              when 0 #use this node
                if request_options[method].is_a?(Regexp)
                  new_node = router.request_node
                  current_nodes[current_node_index] = new_node
                  current_node.create_linear
                  current_node.linear << [request_options[method], new_node]
                elsif request_options[method].is_a?(Array)
                  current_node.create_lookup
                  current_nodes[current_node_index] = request_options[method].map{|val| current_node.lookup[val] ||= router.request_node}
                else
                  current_node.create_lookup
                  current_nodes[current_node_index] = (current_node.lookup[request_options[method]] ||= router.request_node)
                end
              when 1 #this node is farther ahead
                current_nodes[current_node_index] = (current_node.catchall ||= router.request_node)
              when -1 #this method is more important than the current node
                next_node = current_node.dup
                current_node.reset!
                current_node.request_method = method
                redo
              end
            else
              current_node.catchall ||= router.request_node
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

    def find_on_parts(request, parts, extension, params)
      if parts.empty? && extension_node && extension
        parts << extension
        extension_node.find_on_parts(request, parts, extension, params)
      else
        if @linear && !@linear.empty?
          whole_path = parts.join('/')
          next_node = @linear.find do |(tester, node)|
            if tester.is_a?(Regexp) and match = whole_path.match(tester) #and match.index == 0 TODO
              whole_path.slice!(0,match[0].size)
              parts.replace(router.split(whole_path))
              node
            elsif new_params = tester.matches(request.env, parts, whole_path)
              params << new_params
              node
            else
              nil
            end
          end
          return next_node.last.find_on_parts(request, parts, extension, params) if next_node
        end
        if match = @lookup && @lookup[parts.first]
          parts.shift
          match.find_on_parts(request, parts, extension, params)
        elsif @catchall
          params << @catchall.variable.matches(request.env, parts, whole_path)
          parts.shift
          @catchall.find_on_parts(request, parts, extension, params)
        elsif parts.size == 1 && parts.first == '' && (value && value.route.trailing_slash_ignore?)
          parts.shift
          find_on_parts(request, parts, extension, params)
        elsif request_node
          request_node.find_on_request_methods(request)
        elsif @value
          self
        else
          nil
        end
      end
    end

    def create_linear
      @linear ||= []
    end

    def create_lookup
      @lookup ||= {}
    end
  end
  
  class RequestNode < Node
    RequestMethods =  [:request_method, :host, :port, :scheme]
    attr_accessor :request_method

    def find_on_request_methods(request)
      if @request_method
        request_value = request.send(request_method)
        if @linear && !@linear.empty?
          next_node = @linear.find do |(regexp, node)|
            regexp === request_value
          end
          next_node &&= next_node.find_on_request_methods(request)
          return next_node if next_node
        end
        if @lookup and next_node = (@lookup[request_value] && @lookup[request_value].find_on_request_methods(request))
          return next_node
        elsif next_node = (@catchall && @catchall.find_on_request_methods(request))
          return next_node
        end
      end
      
      if @value
        self
      else
        current_node = request_method == :request_method ? Response.unmatched(405, {"Allow" => @lookup.keys.join(", ")}) : nil
      end
    end

  end
  
end
