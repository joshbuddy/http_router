class TestVariable < MiniTest::Unit::TestCase
  def test_variable
    assert_route ':one',      '/two',        {:one => 'two'}
    assert_route 'test/:one', '/test/three', {:one => 'three'}
  end

  def test_variable_vs_static
    static, dynamic = router { add 'one'; add ':one' }
    assert_route dynamic, '/two', {:one => 'two'}
    assert_route static,  '/one'
  end

  def test_variable_with_static_after
    variable, static = router { 
      add '/:var/one'
      add 'one'
    }
    assert_route variable,     '/two/one', {:var => 'two'}
    assert_route static,       '/one'
    assert_route nil,          '/two'
  end

  def test_variable_and_static
    dynamic, static = router {
      add("/foo/:id")
      add("/foo")
    }
    assert_route dynamic, '/foo/id', {:id => 'id'}
    assert_route static,  '/foo'
  end

  def test_variable_mixed_with_static
    static, dynamic = router {
      add("/foo/foo")
      add("/:foo/foo2")
    }
    assert_route dynamic, '/foo/foo2', {:foo => 'foo'}
    assert_route static,  '/foo/foo'
  end

  def test_encoding
    assert_route '/:var', '/%E6%AE%BA%E3%81%99', {:var => "\346\256\272\343\201\231"}
  end

  def test_match_path
    r = router { add %r{/(test123|\d+)} }
    assert_route r, '/test123'
    assert_route r, '/123'
    assert_route nil, '/test123andmore'
    assert_route nil, '/lesstest123'
  end

  def test_format
    assert_route '/test.:format', '/test.html', {:format => 'html'}
  end

  def test_optional_format
    r = router {add('/test(.:format)')}
    assert_route r, '/test.html', {:format => 'html'}
    assert_route r, '/test'
  end

  def test_bare_optional_format
    r = router {add('(.:format)')}
    assert_route r, '/.html', {:format => 'html'}
    assert_route r, '/'
  end

  def test_var_with_format
    assert_route '/:test.:format', '/foo.bar', {:test => 'foo', :format => 'bar'}
  end

  def test_var_with_optional_format
    r = router { add('/:test(.:format)') }
    assert_route r, '/foo.bar', {:test => 'foo', :format => 'bar'}
    assert_route r, '/foo', {:test => 'foo'}
  end

  def test_var_with_optional_format_and_regex
    r = router { add('/:test(.:format)', :format => /[^\.]+/) }
    assert_route r, '/asd@asd.com.json', {:test => 'asd@asd.com', :format => 'json'}
  end

  def test_glob
    assert_route '/test/*variable', 'test/one/two/three', {:variable => ['one', 'two', 'three']}
  end

  def test_glob_with_static
    assert_route '/test/*variable/test', '/test/one/two/three/test', {:variable => ['one', 'two', 'three']}
  end

  def test_glob_with_variable
    assert_route '/test/*variable/:test', '/test/one/two/three', {:variable => ['one', 'two'], :test => 'three'}
  end

  def test_glob_with_format
    assert_route '/test/*variable.:format', 'test/one/two/three.html', {:variable => ['one', 'two', 'three'], :format => 'html'}
  end

  def test_glob_with_optional_format
    assert_route '/test/*variable(.:format)', 'test/one/two/three.html', {:variable => ['one', 'two', 'three'], :format => 'html'}
  end

  def test_glob_with_literal
    assert_route '/test/*variable.html', 'test/one/two/three.html', {:variable => ['one', 'two', 'three']}
  end

  def test_glob_with_regex
    r = router { add('/test/*variable/anymore')}
    assert_route r, '/test/123/345/567/anymore', {:variable => ['123', '345', '567']}
    assert_route nil, '/test/123/345/567'
  end

  def test_regex_and_greedy
    with_regex, with_post, without_regex = router {
      add("/:common_variable/:matched").matching(:matched => /\d+/)
      post("/:common_variable/:unmatched")
      add("/:common_variable/:unmatched")
    }
    assert_route with_regex,    '/common/123',   {:common_variable => 'common', :matched => '123'}
    assert_route without_regex, '/common/other', {:common_variable => 'common', :unmatched => 'other'}
    assert_route with_regex,    Rack::MockRequest.env_for('/common/123', :method => 'POST'),   {:common_variable => 'common', :matched => '123'}
    assert_route with_post, Rack::MockRequest.env_for('/common/other', :method => 'POST'), {:common_variable => 'common', :unmatched => 'other'}
  end

  if //.respond_to?(:names)
    eval "
    def test_match_path_with_groups
      r = router { add(%r{/(?<year>\\d{4})/(?<month>\\d{2})/(?<day>\\d{2})/?}) }
      assert_route r, '/1234/23/56', {:year => '1234', :month => '23', :day => '56'}
    end
    "
  end
end
