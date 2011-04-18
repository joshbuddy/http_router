class TestRequest < MiniTest::Unit::TestCase
  def test_simple_case
    r = router { add('test').post }
    assert_route r, Rack::MockRequest.env_for('/test', :method => 'POST')
    assert_header({'Allow' => 'POST'}, Rack::MockRequest.env_for('/test', :method => 'GET'))
    assert_status(405, Rack::MockRequest.env_for('/test', :method => 'GET'))
  end

  def test_single_app_with_404
    r = router { add('test').post.to{|env| [404, {}, []]} }
    assert_route nil, Rack::MockRequest.env_for('/test', :method => 'POST')
    assert_status(404, Rack::MockRequest.env_for('/test', :method => 'POST'))
  end

  def test_with_optional_parts_and_405
    get, post, delete = router {
      get('test(.:format)')
      post('test(.:format)')
      delete('test(.:format)')
    }
    assert_route get,    Rack::MockRequest.env_for('/test', :method => 'GET')
    assert_route post,   Rack::MockRequest.env_for('/test', :method => 'POST')
    assert_route delete, Rack::MockRequest.env_for('/test', :method => 'DELETE')
    assert_route get,    Rack::MockRequest.env_for('/test.html', :method => 'GET'),    {:format => 'html'}
    assert_route post,   Rack::MockRequest.env_for('/test.html', :method => 'POST'),   {:format => 'html'}
    assert_route delete, Rack::MockRequest.env_for('/test.html', :method => 'DELETE'), {:format => 'html'}
    put = router.call(Rack::MockRequest.env_for('/test', :method => 'PUT'))
    assert_status 405, put
    assert_equal %w{DELETE GET POST}, put[1]['Allow'].split(/\s*,\s*/).sort
  end

  def test_deeply
    test_post, test_post_post, test_get, test_post_get, test_post_catchall, test_catchall = router {
      post("/test")
      post("/test/post")
      get("/test")
      get("/test/post")
      add("/test/post")
      add("/test")
    }
    assert_route test_post,          Rack::MockRequest.env_for('/test', :method => 'POST')
    assert_route test_get,           Rack::MockRequest.env_for('/test', :method => 'GET')
    assert_route test_catchall,      Rack::MockRequest.env_for('/test', :method => 'PUT')
    assert_route test_post_post,     Rack::MockRequest.env_for('/test/post', :method => 'POST')
    assert_route test_post_get,      Rack::MockRequest.env_for('/test/post', :method => 'GET')
    assert_route test_post_catchall, Rack::MockRequest.env_for('/test/post', :method => 'PUT')
  end

  def test_move_node
    post, general = router {
      post("/test").default_destination
      add("/test").default_destination
    }
    assert_route post,    Rack::MockRequest.env_for('/test', :method => 'POST')
    assert_route general, Rack::MockRequest.env_for('/test', :method => 'PUT')
  end

  def test_complex_routing
    host2_post, host2_get, host2, post = router {
      add("/test").post.host('host2')
      add("/test").host('host2').get
      add("/test").host('host2')
      add("/test").post
    }
    assert_route host2,      Rack::MockRequest.env_for('http://host2/test', :method => 'PUT')
    assert_route post,       Rack::MockRequest.env_for('http://host1/test', :method => 'POST')
    assert_route host2_get,  Rack::MockRequest.env_for('http://host2/test', :method => 'GET')
    assert_route host2_post, Rack::MockRequest.env_for('http://host2/test', :method => 'POST')
  end

  def test_regexp
    with, without = router {
      get("/test").host(/host1/)
      get("/test")
    }
    assert_route without, 'http://host2/test'
    assert_route with,    'http://host2.host1.com/test'
  end

  def test_all_routes
    router {
      post("/test").host('host1')
    }
    assert_route router.add("/test").host('host2'), Rack::MockRequest.env_for('http://host2/test', :method => 'POST')
  end

  def test_match_on_scheme
    http, https = router { get("/test").scheme('http'); get("/test").scheme('https') }
    assert_status 405, Rack::MockRequest.env_for('https://example.org/test', :method => 'POST')
  end
end