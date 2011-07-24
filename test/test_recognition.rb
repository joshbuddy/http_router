class TestRecognition < MiniTest::Unit::TestCase
  if //.respond_to?(:names)
    eval <<-EOT
    def test_match_path_with_groups
      r = router { add(%r{/(?<year>\\d{4})/(?<month>\\d{2})/(?<day>\\d{2})/?}) }
      assert_route r, "/1234/23/56", {:year => "1234", :month => "23", :day => "56"}
    end
    EOT
  end

  def test_match
    hello, love80, love8080 = router {
      add('test').arbitrary(Proc.new{|req, params| req.rack.host == 'hellodooly' })
      add("test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
    }
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_less_specific_node
    hello, love80, love8080, general = router {
      add("/test").arbitrary(Proc.new{|req, params| req.rack.host == 'hellodooly' })
      add("/test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("/test").arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
      add("/test")
    }
    assert_route general,  'http://lovelove:8081/test'
    assert_route hello,    'http://hellodooly:8081/test'
    assert_route love80,   'http://lovelove:80/test'
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_match_request
    love80, love8080 = router {
      add("/test").get.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("/test").get.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
    }
    assert_route love80,   'http://lovelove:80/test'
    assert_route love8080, 'http://lovelove:8080/test'
  end

  def test_less_specific_with_request
    love80, love8080, general = router {
      add("test").post.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 80}
      add("test").post.arbitrary(Proc.new{|req, params| req.rack.host == 'lovelove' }).arbitrary{|req, params| req.rack.port == 8080}
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
    assert_route r, '/test', {:test => 'test'}
  end

  def test_continue
    no, yes = router {
      add('test').arbitrary_with_continue{|req, p| req.continue[false]}
      add('test').arbitrary_with_continue{|req, p| req.continue[true]}
    }
    assert_route yes, '/test'
  end

  def test_passing
    passed, working = router {
      add('/').to { |env| throw :pass; [200, {}, ['pass']] }
      add('/').to { |env| [200, {}, ['working']] }
    }
    assert_body 'working', router.call(Rack::MockRequest.env_for('/'))
  end

  def test_non_path_matching
    passed, working = router {
      add(:conditions => {:user_agent => /MSIE/}).to { |env| [200, {}, ['IE']] }
      add('/').to { |env| [200, {}, ['SOMETHING ELSE']] }
    }
    assert_body 'SOMETHING ELSE', router.call(Rack::MockRequest.env_for('/'))
    assert_body 'IE', router.call(Rack::MockRequest.env_for('/', 'HTTP_USER_AGENT' => 'THIS IS MSIE DAWG'))
  end

  def test_passing_with_cascade
    passed, working = router {
      add('/').to { |env| [200, {'X-Cascade' => 'pass'}, ['pass']] }
      add('/').to { |env| [200, {}, ['working']] }
    }
    assert_body 'working', router.call(Rack::MockRequest.env_for('/'))
  end

  def test_request_mutation
    got_this_far = false
    non_matching, matching = router {
      add("/test/:var/:var2/*glob").matching(:var2 => /123/, :glob => /[a-z]+/).get.arbitrary{|env, params| got_this_far = true; false}
      add("/test/:var/:var2/*glob").matching(:var2 => /123/, :glob => /[a-z]+/).get
    }
    assert_route matching, '/test/123/123/asd/aasd/zxcqwe/asdzxc', {:var => '123', :var2 => '123', :glob => %w{asd aasd zxcqwe asdzxc}}
    assert got_this_far, "matching should have gotten this far"
  end

  def test_compiling_uncompiling
    @router = HttpRouter.new
    root = @router.add('/').default_destination
    assert_route root, '/'
    test = @router.add('/test').default_destination
    assert_route root, '/'
    assert_route test, '/test'
  end
end
