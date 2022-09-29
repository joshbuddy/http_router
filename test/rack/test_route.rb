class TestRouteExtensions < MiniTest::Unit::TestCase

  def test_redirect
    router.get("/index.html").redirect("/")
    response = router.call(Rack::MockRequest.env_for("/index.html"))
    assert_header({'Location' => '/'}, response)
    assert_status 302, response
  end

  def test_redirect_with_params
    router.get("/:id.html").redirect('/#{params[:id]}')
    response = router.call(Rack::MockRequest.env_for("/123.html"))
    assert_header({'Location' => '/123'}, response)
    assert_status 302, response
  end

  def test_static_directory
    router.get("/static").static(File.dirname(__FILE__))
    status, headers, body = router.call(Rack::MockRequest.env_for("/static/#{File.basename(__FILE__)}"))
    assert_equal File.join(File.dirname(__FILE__), File.basename(__FILE__)), body.path
  end

  def test_static_file
    router.get("/static-file").static(__FILE__)
    status, headers, body = router.call(Rack::MockRequest.env_for("/static-file"))
    assert_equal __FILE__, body.path
  end

  def test_custom_status
    router.get("/index.html").redirect("/", 303)
    response = router.call(Rack::MockRequest.env_for("/index.html"))
    assert_header({'Location' => '/'}, response)
    assert_status 303, response
  end

  def test_raise_error_on_invalid_status
    assert_raises(ArgumentError) { router.get("/index.html").redirect("/", 200) }
  end

  def test_path_info_from_partial_match
    request_env = nil
    router do
      add("/sidekiq*").to { |env| request_env = env; [200, {}, []] }
    end
    router.call(Rack::MockRequest.env_for("/sidekiq/queues"))
    assert_equal('/queues', request_env['PATH_INFO'])
  end

  def test_script_name_from_partial_match
    request_env = nil
    router do
      add("/sidekiq*").to { |env| request_env = env; [200, {}, []] }
    end
    router.call(Rack::MockRequest.env_for("/sidekiq/queues"))
    assert_equal('/sidekiq', request_env['SCRIPT_NAME'])
  end

  def test_path_info_from_partial_match_of_single
    request_env = nil
    router do
      add("/sidekiq*").to { |env| request_env = env; [200, {}, []] }
    end
    router.call(Rack::MockRequest.env_for("/sidekiq"))
    assert_equal('/', request_env['PATH_INFO'])
  end

  def test_script_name_from_partial_match_of_single
    request_env = nil
    router do
      add("/sidekiq*").to { |env| request_env = env; [200, {}, []] }
    end
    router.call(Rack::MockRequest.env_for("/sidekiq"))
    assert_equal('/sidekiq', request_env['SCRIPT_NAME'])
  end

  def test_path_info_with_encoded_request_path
    request_env = nil
    router do
      add("/sidekiq*").to { |env| request_env = env; [200, {}, []] }
    end
    router.call(Rack::MockRequest.env_for("/sidekiq/queues/some%20path"))
    assert_equal('/queues/some%20path', request_env['PATH_INFO'])
  end

  def test_script_name_with_encoded_request_path
    request_env = nil
    router do
      add("/sidekiq*").to { |env| request_env = env; [200, {}, []] }
    end
    router.call(Rack::MockRequest.env_for("/sidekiq/queues/some%20path"))
    assert_equal('/sidekiq', request_env['SCRIPT_NAME'])
  end
end
