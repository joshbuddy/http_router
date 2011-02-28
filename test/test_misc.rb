class TestMisc < MiniTest::Unit::TestCase
  def test_exceptions
    assert_raises(HttpRouter::AmbiguousRouteException) {HttpRouter.new.add("/:var1(/:var2)(/:var3)").compile}
    assert_raises(HttpRouter::AmbiguousVariableException) {HttpRouter.new.add("/:var1(/:var1)(/:var1)").compile}
    assert_raises(HttpRouter::UnsupportedRequestConditionError) {HttpRouter.new.add("/").condition(:flibberty => 'gibet').compile}
  end

  def test_cloning
    r1 = HttpRouter.new {
      add('/test').name(:test_route).to :test
    }
    r2 = r1.clone

    r2.add('/test2').name(:test).to(:test2)
    assert_equal 2, r2.routes.size

    assert r1.recognize(Rack::Request.new(Rack::MockRequest.env_for('/test2'))).nil?
    assert !r2.recognize(Rack::Request.new(Rack::MockRequest.env_for('/test2'))).nil?
    assert_equal r1.routes.first, r1.named_routes[:test_route]
    assert_equal r2.routes.first, r2.named_routes[:test_route]

    r1.add('/another').name(:test).to(:test2)

    assert_equal r1.routes.size, r2.routes.size
    assert_equal '/another', r1.url(:test)
    assert_equal '/test2',   r2.url(:test)
    assert_equal :test, r1.routes.first.dest
    assert_equal :test, r2.routes.first.dest
  end
end
