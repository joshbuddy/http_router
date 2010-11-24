class TestRackUrlmap < MiniTest::Unit::TestCase

  def test_map_urls
    HttpRouter::Rack.override_rack_urlmap!
    map = Rack::URLMap.new(
      "http://www.example.org/test" => proc {|env| [200, {}, ['test']]},
      "http://www.example.org/:test" => proc {|env| [200, {}, ['variable']]}
    )
    assert_equal 'test',     map.call(Rack::MockRequest.env_for('http://www.example.org/test')).last.join
    assert_equal 'variable', map.call(Rack::MockRequest.env_for('http://www.example.org/whhhaaa')).last.join
  end
end