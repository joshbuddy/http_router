require 'rack'

module CallWithMockRequestMixin
  def call_with_mock_request(url = "/sample", method = "GET", params = Hash.new)
    params.merge!(:method => method)
    request = Rack::MockRequest.new(self)
    request.request(method, url, params)
  end
end

class MockApp
  attr_accessor :status, :headers, :body, :env
  def initialize(body)
    @status  = 200
    @headers = {"Content-Type" => "text/html"}
    @body    = body
  end

  def call(env)
    @env = env
    @headers.merge("Content-Length" => @body.length.to_s)
    [@status, @headers, [@body]]
  end
end