class HttpRouter
  class Response < Struct.new(:path, :params, :extension, :matched_path, :remaining_path)
    attr_reader :params_as_hash, :route

    def initialize(path, params, extension, matched_path, remaining_path)
      raise if matched_path.nil?
      super
      @params_as_hash = path.variable_names.zip(params).inject({}) {|h, (k,v)| h[k] = v; h }
      @params_as_hash[path.extension.name] = extension if path.extension && path.extension.is_a?(Variable)
    end

    def route
      path.route
    end
    
    def dest
      route.dest
    end
    alias_method :destination, :dest
    
    def partial_match?
      remaining_path
    end
  end
end
