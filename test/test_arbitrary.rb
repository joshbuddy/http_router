class TestArbitrary < MiniTest::Unit::TestCase
  def test_match
    hello, love80, love8080 = router {
      add('test').arbitrary(Proc.new{|req, params, dest| req.host == 'hellodooly' })
      add("test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}
      add("test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}
    }
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_less_specific_node
    general, hello, love80, love8080 = router {
      add("/test")
      add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'hellodooly' })
      add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}
      add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}
    }
    assert_route general,  'http://lovelove:8081/test'
    assert_route hello,    'http://hellodooly:8081/test'
    assert_route love80,   'http://lovelove:80/test'
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_match_request
    love80, love8080 = router {
      add("/test").get.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}
      add("/test").get.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}
    }
    assert_route love80,   'http://lovelove:80/test'
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_less_specific_with_request
    love80, love8080, general = router {
      add("test").post.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}
      add("test").post.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}
      add("test").post
    }
    assert_route love8080, Rack::MockRequest.env_for('http://lovelove:8080/test', :method => :post)
    assert_route love80,   Rack::MockRequest.env_for('http://lovelove:80/test', :method => :post)
    assert_route general,  Rack::MockRequest.env_for('/test', :method => :post)
  end

  def test_pass_params
    r = router {
      add(":test").get.arbitrary(Proc.new{|req, params, dest| params[:test] == 'test' })
    }
    assert_route r, '/test'
  end
end