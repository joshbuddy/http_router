class TestGenerate < MiniTest::Unit::TestCase

  def test_static
    router {
      add('/').name(:a)
      add('/test').name(:b)
      add('/test/time').name(:c)
      add('/one/more/what').name(:d)
      add('/test.html').name(:e)
    }
    assert_generate '/', :a
    assert_generate '/test', :b
    assert_generate '/test/time', :c
    assert_generate '/one/more/what', :d
    assert_generate '/test.html', :e
  end

  def test_dynamic
    assert_generate '/test', '/:var', :var => 'test'
    assert_generate '/test', '/:var', 'test'
  end

  def test_array_with_extras
    assert_generate '/test?query=string', '/:var', :var => 'test', :query => 'string'
    assert_generate '/test?query=string', '/:var', 'test', :query => 'string'
  end

  def test_multiple_dynamics
    assert_generate '/one/two', "/:var/:baz", :var => 'one', :baz => 'two'
    assert_generate '/one/two', "/:var/:baz", 'one', 'two'
  end

  def test_extension
    assert_generate '/test.html', "/test.:format", :format => 'html'
    assert_generate '/test.html', "/test.:format", 'html'
  end

  def test_optional_extension
    assert_generate '/test.html', "/test(.:format)", :format => 'html'
    assert_generate '/test.html', "/test(.:format)", 'html'
    assert_generate '/test',      "/test(.:format)"
  end

  def test_variable_with_extension
    assert_generate '/test.html', "/:var.:format", :var => 'test', :format => 'html'
    assert_generate '/test.html', "/:var.:format", 'test', 'html'
  end

  def test_variable_with_optional_extension
    assert_generate '/test.html', "/:var(.:format)", :var => 'test', :format => 'html'
    assert_generate '/test.html', "/:var(.:format)", 'test', 'html'
    assert_generate '/test',      "/:var(.:format)", :var => 'test'
    assert_generate '/test',      "/:var(.:format)", 'test'
  end

  def test_optionals
    assert_generate '/var',      "/:var1(/:var2)", 'var'
    assert_generate '/var/fooz', "/:var1(/:var2)", 'var', 'fooz'
    assert_generate '/var',      "/:var1(/:var2)", :var1 => 'var'
    assert_generate '/var/fooz', "/:var1(/:var2)", :var1 => 'var', :var2 => 'fooz'
    assert_raises(HttpRouter::UngeneratableRouteException) { router.url(router.add("/:var1(/:var2)").to(:test), :var2 => 'fooz') }
  end

  def test_optionals_with_format
    assert_generate '/var',           "/:var1(/:var2.:format)", 'var'
    assert_generate '/var/fooz.html', "/:var1(/:var2.:format)", 'var', 'fooz', 'html'
    assert_generate '/var',           "/:var1(/:var2.:format)", :var1 => 'var'
    assert_generate '/var/fooz.html', "/:var1(/:var2.:format)", :var1 => 'var', :var2 => 'fooz', :format => 'html'
  end

  def test_nested_optionals
    assert_generate '/var',          "/:var1(/:var2(/:var3))", 'var'
    assert_generate '/var/fooz',     "/:var1(/:var2(/:var3))", 'var', 'fooz'
    assert_generate '/var/fooz/baz', "/:var1(/:var2(/:var3))", 'var', 'fooz', 'baz'
    assert_generate '/var',          "/:var1(/:var2(/:var3))", :var1 => 'var'
    assert_generate '/var/fooz',     "/:var1(/:var2(/:var3))", :var1 => 'var', :var2 => 'fooz'
    assert_generate '/var/fooz/baz', "/:var1(/:var2(/:var3))", :var1 => 'var', :var2 => 'fooz', :var3 => 'baz'
  end

  def test_default_value
    assert_generate "/123?page=1", router.add("/:var").default(:page => 1),         123
    assert_generate "/1/123",      router.add("/:page/:entry").default(:page => 1), :entry => '123'
  end

  def test_nil_values
    assert_generate '/url', "/url(/:var)", :var => nil
  end

  def test_raise
    r = router { add(':var').matching(:var => /\d+/) }
    assert_raises(HttpRouter::InvalidRouteException) { router.url(r, 'asd') }
  end
end
