class TestVariable < MiniTest::Unit::TestCase
  def test_variable
    assert_route router.add(':one'),      '/two',        {:one => 'two'}
    assert_route router.add('test/:one'), '/test/three', {:one => 'three'}
  end

  def test_variable_vs_static
    dynamic, static = router { 
      add ':one'
      add 'one'
    }
    assert_route dynamic, '/two', {:one => 'two'}
    assert_route static,  '/one'
  end

  def test_variable_vs_glob
    glob, variable = router { 
      add '*var'
      add ':var'
    }
    assert_route variable,     '/two',     {:var => 'two'}
    assert_route glob,         '/two/two', {:var => %w{two two}}
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
end
