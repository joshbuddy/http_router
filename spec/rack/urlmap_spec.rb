require 'spec_helper'

describe "Rack::Urlmap replacement" do
  it "should map urls" do
    HttpRouter::Rack.override_rack_urlmap!
    map = Rack::URLMap.new(
      "http://www.example.org/test" => proc {|env| [200, {}, ['test']]},
      "http://www.example.org/:test" => proc {|env| [200, {}, ['variable']]}
    )
    map.call(Rack::MockRequest.env_for('http://www.example.org/test')).last.join.should == 'test'
    map.call(Rack::MockRequest.env_for('http://www.example.org/whhhaaa')).last.join.should == 'variable'
  end
end