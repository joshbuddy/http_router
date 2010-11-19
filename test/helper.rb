require 'minitest/autorun'

class MiniTest::Unit::TestCase
  def router(&blk)
    @router ||= HttpRouter.new(&blk)
    if blk
      @router.routes.size ? @router.routes.first : @router.routes
    else
      @router
    end
  end

  def assert_body(expect, response)
    body = case expect
    when Array  then []
    when String then ""
    else             raise
    end
    response.last.each {|p| body << p}
    assert_equal expect, body
  end
  
  def assert_route(route, request, params = nil, &blk)
    if route
      dest = "Routing to #{route.to_s}"
      route.to{|env| Rack::Response.new(dest).finish}
    end
    env = request.is_a?(String) ? Rack::MockRequest.env_for(request) : request
    response = @router.call(env)
    if route
      assert_equal [dest], response.last.body
    else
      assert_equal 404, response.first
    end
    if params
      assert_equal params.size, env['router.params'].size
      params.each { |k, v| assert_equal v, env['router.params'][k] }
    end
  end
end
