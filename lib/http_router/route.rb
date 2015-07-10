require 'set'

class HttpRouter
  class Route
    # The list of HTTP request methods supported by HttpRouter.
    VALID_HTTP_VERBS = %w{GET POST PUT DELETE HEAD OPTIONS TRACE PATCH OPTIONS LINK UNLINK}
    VALID_HTTP_VERBS_WITHOUT_GET = VALID_HTTP_VERBS - %w{GET}

    attr_reader :default_values, :router, :match_partially, :other_hosts, :paths, :request_methods, :name
    attr_accessor :match_partially, :router, :host, :user_agent, :ignore_trailing_slash,
                  :path_for_generation, :path_validation_regex, :generator, :scheme, :original_path, :dest

    def create_clone(new_router)
      r = clone
      r.dest = (begin; dest.clone; rescue; dest; end)
      r
    end

    def to_s
      "#<HttpRouter:Route #{object_id} @path_for_generation=#{path_for_generation.inspect}>"
    end

    def matches_with(var_name)
      @match_with && @match_with[:"#{var_name}"]
    end

    def name=(name)
      @name = name
      router.named_routes[name] << self if router
    end
  end
end
