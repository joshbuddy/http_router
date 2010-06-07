require 'spec_helper'

describe "HttpRouter as middleware" do
  before(:each) do
    @builder = Rack::Builder.new do
      use(HttpRouter, :middleware => true) {
        add('/test').name(:test).to(:test)
      }
    end
  end

  it "should always have the router" do
    @builder.run proc{|env| [200, {}, [env['router'].url(:test)]]}
    @builder.call(Rack::MockRequest.env_for('/some-path')).last.join.should == '/test'
  end

  it "should stash the match if it exists" do
    @builder.run proc{|env| [200, {}, [env['router.response'].dest.to_s]]}
    @builder.call(Rack::MockRequest.env_for('/test')).last.join.should == 'test'
  end
end

