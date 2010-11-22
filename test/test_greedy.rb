class TestGreedy < MiniTest::Unit::TestCase
  def test_mix_regex_with_greedy
    regex, greedy = router { 
      add("/:test/number").matching(:test => /\d+/)
      add("/:test/anything")
    }
    assert_route regex, '/123/number', {:test => '123'}
    assert_route greedy, '/123/anything', {:test => '123'}
  end

  def test_trailing_slash
    assert_route router.add("/:test").matching(:test => /.*/), '/test/', {:test => 'test/'}
  end

  def test_extension
    assert_route router.add("/:test").matching(:test => /.*/), '/test.html', {:test => 'test.html'}
  end

  def test_match_at_beginning
    r = router { add(':test', :test => /\d+/)}
    assert_route r, '/123', {:test => '123'}
    assert_route nil, '/a123'
  end
end
