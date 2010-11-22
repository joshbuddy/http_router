class TestInterstitial < MiniTest::Unit::TestCase
  def test_recognize
    assert_route '/one-:variable-time', '/one-value-time', {:variable => 'value'}
  end

  def test_regex
    r = router { add('/one-:variable-time').matching(:variable => /\d+/) }
    assert_route r,   '/one-123-time', {:variable => '123'}
    assert_route nil, '/one-value-time'
  end

  def test_regex_as_options
    r = router { add('/one-:variable-time', :variable => /\d+/) }
    assert_route r,   '/one-123-time', {:variable => '123'}
    assert_route nil, '/one-value-time'
  end

  def test_extension
    assert_route 'hey.:greed.html', '/hey.greedybody.html', {:greed => 'greedybody'}
  end

  def test_multi
    r1, r2, r3, r4, r5, r6 = router {
      add('/:var1')
      add('/:var1-:var2')
      add('/:var1-:var2-:var3')
      add('/:var1-:var2-:var3-:var4')
      add('/:var1-:var2-:var3-:var4-:var5')
      add('/:var1-:var2-:var3-:var4-:var5-:var6')
    }
    assert_route r1, '/one',                           {:var1 => 'one'}
    assert_route r2, '/one-value',                     {:var1 => 'one', :var2 => 'value'}
    assert_route r3, '/one-value-time',                {:var1 => 'one', :var2 => 'value', :var3 => 'time'}
    assert_route r4, '/one-value-time-one',            {:var1 => 'one', :var2 => 'value', :var3 => 'time', :var4 => 'one'}
    assert_route r5, '/one-value-time-one-variable',   {:var1 => 'one', :var2 => 'value', :var3 => 'time', :var4 => 'one', :var5 => 'variable'}
    assert_route r6, '/one-value-time-one-value-time', {:var1 => 'one', :var2 => 'value', :var3 => 'time', :var4 => 'one', :var5 => 'value', :var6 => 'time'}    
  end
  
  def test_regex_with_mutliple_variables
    with_regex, without_regex = router {
      add("/:common_variable.:matched").matching(:matched => /\d+/)
      add("/:common_variable.:unmatched")
    }
    assert_route with_regex,    '/common.123',   {:common_variable => 'common', :matched => '123'}
    assert_route without_regex, '/common.other', {:common_variable => 'common', :unmatched => 'other'}
  end
end
