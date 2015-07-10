class TestMisc < MiniTest::Unit::TestCase

  def test_cloning
    r1 = HttpRouter.new { add('/test', :name => :test_route).to(:test) }
    r2 = r1.clone

    r2.add('/test2', :name => :test).to(:test2)
    assert_equal 2, r2.routes.size

    matches, other_methods = r1.recognize(Rack::Request.new(Rack::MockRequest.env_for('/test2')))
    assert_equal nil, matches
    assert r2.recognize(Rack::MockRequest.env_for('/test2')).first
    assert_equal r1.routes.size, 1
    assert_equal r2.routes.size, 2

    r1.add('/another', :name => :test).to(:test2)

    assert_equal r1.routes.size, r2.routes.size
    assert_equal '/another', r1.path(:test)
    assert_equal '/test2',   r2.path(:test)
    assert_equal :test, r1.routes.first.dest
    assert_equal :test, r2.routes.first.dest
  end

  def test_reseting
    router = HttpRouter.new
    r = router.add('/hi').to(:test)
    matches, other_methods = router.recognize(Rack::MockRequest.env_for('/hi'))
    assert_equal r, matches.first.route
    router.reset!
    assert_equal nil, router.recognize(Rack::MockRequest.env_for('/hi')).first
  end

  def test_redirect_trailing_slash
    r = HttpRouter.new(:redirect_trailing_slash => true) { add('/hi').to(:test) }
    response = r.call(Rack::MockRequest.env_for('/hi/'))
    assert_equal 302, response.first
    assert_equal '/hi', response[1]['Location']
  end

  def test_multi_recognize
    r1, r2, r3, r4 = router {
      add('/hi/there')
      add('/:var/:var2')
      add('/hi/:var2')
      add('/:var1/there')
    }
    response = router.recognize(Rack::MockRequest.env_for('/hi/there'))
    assert_equal [r1, r2, r3, r4], response.first.map{|resp| resp.path.route}
    response = router.recognize(Rack::MockRequest.env_for('/hi/var'))
    assert_equal [r2, r3], response.first.map{|resp| resp.path.route}
    response = router.recognize(Rack::MockRequest.env_for('/you/there'))
    assert_equal [r2, r4], response.first.map{|resp| resp.path.route}
  end

  def test_multi_name_gen
    r = router
    r.add('/', :name => :index).default_destination
    r.add('/:name', :name => :index).default_destination
    r.add('/:name/:category', :name => :index).default_destination
    assert_equal '/', r.path(:index)
    assert_equal '/name', r.path(:index, 'name')
    assert_equal '/name/category', r.path(:index, 'name', 'category')
  end

  def test_yielding_from_recognize
    r = HttpRouter.new
    r1 = r.add('/:name').default_destination
    r2 = r.add('/:name').default_destination
    r3 = r.add('/:name').default_destination
    matches = []
    r.recognize(Rack::MockRequest.env_for('/test')) { |r| matches << r.route }
    assert_equal [r1, r2, r3], matches
  end

  def test_regex_generation
    r = router
    r.add(%r|/test/.*|, :path_for_generation => '/test/:variable', :name => :route).default_destination
    assert_equal '/test/var', r.path(:route, "var")
  end

  def test_too_many_params
    r = router
    r.add(%r|/test/.*|, :path_for_generation => '/test/:variable', :name => :route).default_destination
    assert_equal '/test/var', r.path(:route, "var")
    assert_equal '/test/var', r.path(:route, :variable => "var")
    assert_raises(HttpRouter::InvalidRouteException) { r.path(:route) }
  end

  def test_ambigiuous_parameters_in_route
    r = router
    r.add("/abc/:id/test/:id", :name => :route).default_destination
    assert_raises(HttpRouter::AmbiguousVariableException) { r.path(:route, :id => 'fail') }
  end

  def test_public_interface
    methods = HttpRouter.public_instance_methods.map(&:to_sym)
    assert methods.include?(:url_mount)
    assert methods.include?(:url_mount=)
    assert methods.include?(:call)
    assert methods.include?(:recognize)
    assert methods.include?(:url)
    assert methods.include?(:pass_on_response)
    assert methods.include?(:ignore_trailing_slash?)
    assert methods.include?(:redirect_trailing_slash?)
    assert methods.include?(:process_destination_path)
    assert methods.include?(:rewrite_partial_path_info)
    assert methods.include?(:rewrite_path_info)
    assert methods.include?(:extend_route)
  end

  def test_to_s_and_inspect
    router = HttpRouter.new
    router.add('/').to(:test)
    router.add('/test').to(:test2)
    router.post('/test').to(:test3)
    assert router.to_s.match(/^#<HttpRouter:0x[0-9a-f-]+ number of routes \(3\) ignore_trailing_slash\? \(true\) redirect_trailing_slash\? \(false\)>$/)
    assert router.inspect.match(/^#<HttpRouter:0x[0-9a-f-]+ number of routes \(3\) ignore_trailing_slash\? \(true\) redirect_trailing_slash\? \(false\)>/)
    assert router.inspect.match(/Path: "\/test" for route unnamed route to :test3/)
  end

  def test_naming_route_with_no_router
    route = HttpRouter::Route.new
    route.name = 'named_route'
    assert_equal 'named_route', route.name
  end
end
