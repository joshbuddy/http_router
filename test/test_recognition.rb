class TestRecognition < MiniTest::Unit::TestCase
  if //.respond_to?(:names)
    eval <<-EOT
    def test_match_path_with_groups
      r = router { add(%r{/(?<year>\\d{4})/(?<month>\\d{2})/(?<day>\\d{2})/?}) }
      assert_route r, "/1234/23/56", {:year => "1234", :month => "23", :day => "56"}
    end
    EOT
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

  def test_compiling_uncompiling
    @router = router
    root = @router.add('/').default_destination
    assert_route root, '/'
    test = @router.add('/test').default_destination
    assert_route root, '/'
    assert_route test, '/test'
  end
end
