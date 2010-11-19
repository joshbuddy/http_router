class TestVariable < MiniTest::Unit::TestCase
   "should ignore" do
    route = @router.add("/test").to(:test)
    @router.recognize(Rack::MockRequest.env_for('/test/')).route.should == route
  end

  it "should not recognize when used with the /? syntax and ignore_trailing_slash disabled" do
    @router = HttpRouter.new(:ignore_trailing_slash => false)
    route = @router.add("/test/?").to(:test)
    @router.recognize(Rack::MockRequest.env_for('/test/')).route.should == route
  end

  it "should recognize when used with the /? syntax and ignore_trailing_slash enabled" do
    @router = HttpRouter.new(:ignore_trailing_slash => false)
    route = @router.add("/test").to(:test)
    @router.recognize(Rack::MockRequest.env_for('/test/')).should be_nil
  end

  it "should not capture normally" do
    route = @router.add("/:test").to(:test)
    @router.recognize(Rack::MockRequest.env_for('/test/')).params.first.should == 'test'
  end
  
  it "should recognize trailing slashes when there are other more specific routes near by" do
    @router = HttpRouter.new
    route = @router.add("/foo").to(:foo)
    route = @router.add("/foo/:bar/:id").to(:foo_bar)
    @router.recognize(Rack::MockRequest.env_for('/foo')).dest.should == :foo
    @router.recognize(Rack::MockRequest.env_for('/foo/')).dest.should == :foo
    @router.recognize(Rack::MockRequest.env_for('/foo/5/10')).dest.should == :foo_bar
  end
end