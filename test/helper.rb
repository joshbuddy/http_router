# encoding: utf-8
require 'minitest/autorun'
require 'phocus'

class HttpRouter::Route
  def default_destination
    to{|env| Rack::Response.new("Routing to #{to_s}").finish}
  end
end

class MiniTest::Unit::TestCase

  def router(opts = nil, &blk)
    @router ||= HttpRouter.new(opts, &blk)
    if blk
      @router.routes.each { |route| route.default_destination if route.dest.nil? }
      @router.routes.size > 1 ? @router.routes : @router.routes.first
    else
      @router
    end
  end

  def assert_body(expect, response)
    response = router.call(response) if response.is_a?(Hash)
    body = case expect
    when Array  then []
    when String then ""
    else             raise
    end
    response.last.each {|p| body << p}
    assert_equal expect, body
  end

  def assert_header(header, response)
    response = Rack::MockRequest.env_for(response) if response.is_a?(String)
    response = router.call(response) if response.is_a?(Hash)
    header.each{|k, v| assert_equal v, response[1][k]}
  end

  def assert_status(status, response)
    response = Rack::MockRequest.env_for(response) if response.is_a?(String)
    response = router.call(response) if response.is_a?(Hash)
    assert_equal status, response.first
  end

  def assert_route(route, request, params = nil, &blk)
    if route.is_a?(String)
      router.reset!
      route = router.add(route)
    end
    dest = "Routing to #{route.to_s}"
    route.to{|env| Rack::Response.new(dest).finish} if route && route.dest.nil?
    request = Rack::MockRequest.env_for(request) if request.is_a?(String)
    response = @router.call(request)
    if route
      assert_equal [dest], response.last.body
      if params
        raise "Params was nil, but you expected params" if request['router.params'].nil?
        assert_equal params.size, request['router.params'].size
        params.each { |k, v| assert_equal v, request['router.params'][k] }
      elsif !request['router.params'].nil? and !request['router.params'].empty?
        raise "Wasn't expecting any parameters, got #{request['router.params'].inspect}"
      end
    else
      assert_equal 404, response.first
    end
  end

  def assert_generate(path, route, *args)
    if route.is_a?(String)
      router.reset!
      route = router.add(route)
    end
    route.to{|env| Rack::Response.new("Routing to #{route.to_s}").finish} if route && route.respond_to?(:to) && !route.dest
    assert_equal path.gsub('[','%5B').gsub(']','%5D'), router.url(route, *args)
  end
end
