class TestMisc < MiniTest::Unit::TestCase
  def test_cloning
    r1 = HttpRouter.new { add('/test').name(:test_route).to(:test) }
    r2 = r1.clone

    r2.add('/test2').name(:test).to(:test2)
    assert_equal 2, r2.routes.size

    assert_equal nil, r1.recognize(Rack::Request.new(Rack::MockRequest.env_for('/test2')))
    assert r2.recognize(Rack::MockRequest.env_for('/test2'))
    assert_equal r1.routes.first, r1.named_routes[:test_route]
    assert_equal r2.routes.first, r2.named_routes[:test_route]

    r1.add('/another').name(:test).to(:test2)

    assert_equal r1.routes.size, r2.routes.size
    assert_equal '/another', r1.url(:test)
    assert_equal '/test2',   r2.url(:test)
    assert_equal :test, r1.routes.first.dest
    assert_equal :test, r2.routes.first.dest
  end

  def test_reseting
    r = HttpRouter.new { add('/hi').to(:test) }
    assert r.recognize(Rack::MockRequest.env_for('/hi'))
    r.reset!
    assert !r.recognize(Rack::MockRequest.env_for('/hi'))
  end
end
