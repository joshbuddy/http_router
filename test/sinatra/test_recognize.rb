require "sinatra"
require "http_router/interface/sinatra"

module CallWithMockRequestMixin
  def call_with_mock_request(url = "/sample", method = "GET", params = Hash.new)
    params.merge!(:method => method)
    request = Rack::MockRequest.new(self)
    request.request(method, url, params)
  end
end

class TestRecognize < MiniTest::Unit::TestCase

  def setup
    @app = Sinatra.new { register HttpRouter::Interface::Sinatra::Extension }
    @app.extend(CallWithMockRequestMixin)
    @app.reset!
  end

  def test_basic
    response = @app.call_with_mock_request('/bar')
    assert_equal 404, response.status
  end
  
  def test_map_index
    @app.get("/") { "index" }
    response = @app.call_with_mock_request('/')
    assert_equal 200, response.status
    assert_equal "index", response.body
  end
  
  def test_trailing_slash
    @app.get("/foo") { "foo" }
    response = @app.call_with_mock_request('/foo')
    assert_equal 200, response.status
    assert_equal "foo", response.body
    response = @app.call_with_mock_request('/foo/')
    assert_equal 200, response.status
    assert_equal "foo", response.body
  end
  
  def test_trailing_slash2
    @app.get("/foo") { "foo" }
    @app.get("/foo/bar") { "bar" }
    response = @app.call_with_mock_request('/foo')
    assert_equal 200, response.status
    assert_equal "foo", response.body
    response = @app.call_with_mock_request('/foo/bar')
    assert_equal 200, response.status
    assert_equal "bar", response.body
    response = @app.call_with_mock_request('/foo/')
    assert_equal 200, response.status
    assert_equal "foo", response.body
    response = @app.call_with_mock_request('/foo/bar/')
    assert_equal 200, response.status
    assert_equal "bar", response.body
  end
  
  def test_trailing_slash_with_optional_param
    @app.get("/foo/(:bar)") { params[:bar] }
    @app.get("/bar(/:foo)") { params[:foo] }
    response = @app.call_with_mock_request('/foo/bar')
    assert_equal 200, response.status
    assert_equal "bar", response.body
    response = @app.call_with_mock_request('/bar/foo')
    assert_equal 200, response.status
    assert_equal "foo", response.body
    response = @app.call_with_mock_request('/bar')
    assert_equal 200, response.status
    assert_equal "", response.body
    response = @app.call_with_mock_request('/bar/')
    assert_equal 200, response.status
    assert_equal "", response.body
  end

  def test_trailing_question_mark
    @app.get("/foo/?") { "foo" }
    response = @app.call_with_mock_request('/foo')
    assert_equal 200, response.status
    assert_equal "foo", response.body
    response = @app.call_with_mock_request('/foo/')
    assert_equal 200, response.status
    assert_equal "foo", response.body
  end
  
  def test_map_basic
    @app.get('/hi', :name => :hi) { generate(:hi) }
    response = @app.call_with_mock_request('/hi')
    assert_equal 200, response.status
    assert_equal "/hi", response.body
  end

  def test_map_basic2
    @app.get('/hi', :name => :hi) { generate(:hi) }
    response = @app.call_with_mock_request('/hi/')
    assert_equal 200, response.status
    assert_equal "/hi", response.body
  end
  
  def test_map_param
    @app.get('/hi/:id', :name => :hi) { generate(:hi, :id => 18) }
    response = @app.call_with_mock_request('/hi/1')
    assert_equal 200, response.status
    assert_equal "/hi/18", response.body
  end
  
  def test_map_param2
    @app.get('/hi-:id', :name => :hi) { generate(:hi, :id => 18) }
    response = @app.call_with_mock_request('/hi-1')
    assert_equal 200, response.status
    assert_equal "/hi-18", response.body
  end
  
  def test_map_complex
    @app.get('/hi/:foo/:bar/:baz(.:format)') { "/#{params[:foo]}/#{params[:bar]}/#{params[:baz]}/#{params[:format]}" }
    response = @app.call_with_mock_request('/hi/foo/bar/baz')
    assert_equal 200, response.status
    assert_equal "/foo/bar/baz/", response.body
    response = @app.call_with_mock_request('/hi/foo/bar-bax/baz')
    assert_equal 200, response.status
    assert_equal "/foo/bar-bax/baz/", response.body
  end

  def test_map_regexp
    @app.get('/numbers/:digits', :matching => { :digits => /\d+/ }) { params[:digits] }
    response = @app.call_with_mock_request('/numbers/2010')
    assert_equal 200, response.status
    assert_equal "2010", response.body
  end

  def test_not_map_regex
    @app.get('/numbers/:digits', :matching => { :digits => /\d+/ }) { params[:digits] }
    response = @app.call_with_mock_request('/numbers/nan')
    assert_equal 404, response.status
  end

  def test_404
    response = @app.call_with_mock_request('/bar')
    assert_equal 404, response.status
    assert_match response.body, /Sinatra doesn't know this ditty/
  end

  def test_405
    @app.post('/bar') { 'found' }
    @app.put('/bar') { 'found' }
    response = @app.call_with_mock_request('/bar')
    assert_equal 405, response.status
    assert_equal ['POST', 'PUT'], response.headers['Allow'].split(/\s*,\s*/).sort
  end
end
