require 'set'

class HttpRouter
  class Route
    VALID_HTTP_VERBS = %w{GET POST PUT DELETE HEAD OPTION}

    attr_reader :default_values, :router, :match_partially, :other_hosts, :paths, :request_methods
    attr_accessor :match_partially, :router, :host, :user_agent, :name, :ignore_trailing_slash,
                  :path_for_generation, :path_validation_regex, :generator, :scheme

    def add_default_values(hash)
      @default_values ||= {}
      @default_values.merge!(hash)
    end

    def dest
      @dest
    end

    def dest=(d)
      @dest = d
    end

    def add_match_with(matchers)
      @match_with ||= {}
      @match_with.merge!(matchers)
    end

    def add_other_host(hosts)
      (@other_hosts ||= []).concat(hosts)
    end

    def add_path(path)
      (@paths ||= []) << path
    end

    def add_request_method(methods)
      @request_methods ||= Set.new
      methods = [methods] unless methods.is_a?(Array)
      methods.each do |method|
        method = method.to_s.upcase
        raise unless VALID_HTTP_VERBS.include?(method)
        @router.known_methods << method
        @request_methods << method
      end
    end

    def clone(new_router)
      r = super()
      r.dest = (begin; dest.clone; rescue; dest; end)
      r
    end

    def to_s
      "#<HttpRouter:Route #{object_id} @path_for_generation=#{path_for_generation.inspect}>"
    end

    def matches_with(var_name)
      @match_with && @match_with[:"#{var_name}"]
    end

    def max_param_count
      @generator.max_param_count
    end

    def url(*args)
      @generator.url(*args)
    rescue InvalidRouteException
      nil
    end

    def full_url(*args)
      @generator.full_url(*args)
    rescue InvalidRouteException
      nil
    end

    def path(*args)
      @generator.path(*args)
    rescue InvalidRouteException
      nil
    end

    def name=(name)
      @name = name
      @router.named_routes[name] << self
    end
  end
end