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

  def test_chainable
    router.get("/index.html").redirect("/").name(:root)
    assert_equal "/index.html", router.url(:root)
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
end
