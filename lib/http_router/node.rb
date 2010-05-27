class HttpRouter
  class Node
    attr_accessor :value, :variable, :catchall
    attr_reader :linear, :lookup, :request_node, :extension_node

    def initialize
      reset!
    end

    def reset!
      @linear = []
      @lookup = {}
      @catchall = nil
    end

    def add(val)
      if val.is_a?(Variable)
        if val.matches_with
          new_node = Node.new
          @linear << [val, new_node]
          new_node
        else
          @catchall ||= Node.new
          @catchall.variable = val
          @catchall
        end
      elsif val.is_a?(Regexp)
        @linear << [val, Node.new]
        @linear.last.last
      else
        @lookup[val] ||= Node.new
      end
    end
    
    def add_extension(ext)
      @extension_node ||= Node.new
      @extension_node.add(ext)
    end
    
    def add_request_methods(options)
      if !options.empty?
        generate_request_method_tree(options)
      elsif @request_node
        current_node = @request_node
        while current_node.request_method
          current_node = (current_node.catchall ||= RequestNode.new)
        end
        [current_node]
      else
        [self]
      end
    end
    
    protected

    def transplant_value
      if @value
        target_node = @request_node
        while target_node.request_method
          target_node = (target_node.catchall ||= RequestNode.new)
        end
        target_node.value = @value
        @value = nil
      end
    end
    
    def generate_request_method_tree(request_options)
      raise if (request_options.keys & RequestNode::RequestMethods).size != request_options.size
      
      
      current_nodes = [@request_node ||= RequestNode.new]
      RequestNode::RequestMethods.each do |method|
        current_nodes.each_with_index do |current_node, current_node_index|
          if request_options[method]  #we care about the method
            if current_node  # and we have to pay attention to what currently is there.
              unless current_node.request_method
                current_node.request_method = method
              end
            
              case RequestNode::RequestMethods.index(method) <=> RequestNode::RequestMethods.index(current_node.request_method)
              when 0 #use this node
                if request_options[method].is_a?(Regexp)
                  current_node = RequestNode.new
                  current_node.linear << [request_options[method], current_node]
                elsif request_options[method].is_a?(Array)
                  current_nodes[current_node_index] = request_options[method].map{|val| current_node.lookup[val] ||= RequestNode.new}
                else
                  current_nodes[current_node_index] = (current_node.lookup[request_options[method]] ||= RequestNode.new)
                end
              when 1 #this node is farther ahead
                current_nodes[current_node_index] = (current_node.catchall ||= RequestNode.new)
                redo
              when -1 #this method is more important than the current node
                new_node = RequestNode.new
                new_node.request_method = method
                new_node.catchall = current_node
                current_nodes[current_node_index] = new_node
                redo
              end
            else
              current_nodes[current_node_index] = RequestNode.new
              redo
            end
          elsif !current_node
            @request_node = RequestNode.new
            current_nodes[current_node_index] = @request_node
            redo
          else
            current_node.catchall ||= RequestNode.new
          end
        end
        current_nodes.flatten!
      end
      transplant_value
      current_nodes
    end

    def find_on_request_methods(request)
      current_node = self
      if current_node && current_node.request_node
        current_node = current_node.request_node
        while current_node
          previous_node = current_node
          break if current_node.nil? || current_node.is_a?(RoutingError) || current_node.value
          request_value = request.send(current_node.request_method)
          unless current_node.linear.empty?
            next_node = current_node.linear.find do |(regexp, node)|
              regexp === request_value
            end
            if next_node
              current_node = next_node.last
              next
            end
          end
          current_node = current_node.lookup[request_value] || current_node.catchall
          if current_node.nil?
            current_node = previous_node.request_method == :request_method ? RoutingError.new(405, {"Allow" => previous_node.lookup.keys.join(", ")}) : nil
          else
            current_node
          end
        end
      end
      current_node
    end

  end
  
  class RequestNode < Node
    RequestMethods =  [:request_method, :host, :port, :scheme]
    attr_accessor :request_method
  end
  
end
