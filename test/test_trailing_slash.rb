class TestVariable < MiniTest::Unit::TestCase
  def test_ignore_trailing_slash
    assert_route router.add('/test'), '/test/'
  end

  def test_ignore_trailing_slash_enabled
    router(:ignore_trailing_slash => false).add('/test/?')
    assert_route nil, '/test/'
  end

  def test_capture_with_trailing_slash
    assert_route router.add('/:test'), '/test/', {:test => 'test'}
  end

  def test_trailing_slash_confusion
    more_general, more_specific = router {
      add('foo')
      add('foo/:bar/:id')
    }
    assert_route more_general, '/foo'
    assert_route more_general, '/foo/'
    assert_route more_specific, '/foo/5/10', {:bar => '5', :id => '10'}
  end
end