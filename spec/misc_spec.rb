describe "HttpRouter" do
  before(:each) do
    @router = HttpRouter.new
  end

  context "route adding" do
    it "should work with options too" do
      route = @router.add('/:test', :conditions => {:request_method => %w{HEAD GET}, :host => 'host1'}, :default_values => {:page => 1}, :matching => {:test => /^\d+/}, :name => :foobar).to :test
      @router.recognize(Rack::MockRequest.env_for('http://host2/variable', :method => 'POST')).should be_nil
      @router.recognize(Rack::MockRequest.env_for('http://host1/variable', :method => 'POST')).should be_nil
      @router.recognize(Rack::MockRequest.env_for('http://host2/123',      :method => 'POST')).matched?.should be_false
      @router.recognize(Rack::MockRequest.env_for('http://host1/123',      :method => 'POST')).matched?.should be_false
      @router.recognize(Rack::MockRequest.env_for('http://host1/123',      :method => 'GET' )).route.dest.should == :test
      @router.url(:foobar, 'what').should == '/what?page=1'
    end
  end

  context "instance_eval block" do
    it "run the routes" do
      HttpRouter.new {
        add('/test').to :test
      }.recognize(Rack::MockRequest.env_for('/test', :method => 'GET')).dest.should == :test
    end
  end

  context "exceptions" do
    it "should be smart about multiple optionals" do
      proc {@router.add("/:var1(/:var2)(/:var3)").compile}.should raise_error(HttpRouter::AmbiguousRouteException)
    end

    it "should raise on identical variable name" do
      proc {@router.add("/:var1(/:var1)(/:var1)").compile}.should raise_error(HttpRouter::AmbiguousVariableException)
    end

    it "should raise on unsupported request methods" do
      proc {@router.add("/").condition(:flibberty => 'gibet').compile}.should raise_error(HttpRouter::UnsupportedRequestConditionError)
    end
  end

  context "cloning" do
    it "clone the routes" do
      r1 = HttpRouter.new {
        add('/test').name(:test_route).to :test
      }
      r2 = r1.clone
      
      r2.add('/test2').name(:test).to(:test2)
      r2.routes.size.should == 2
      
      r1.recognize(Rack::MockRequest.env_for('/test2')).should be_nil
      r2.recognize(Rack::MockRequest.env_for('/test2')).should_not be_nil
      r1.named_routes[:test_route].should == r1.routes.first
      r2.named_routes[:test_route].should == r2.routes.first
      
      r1.add('/another').name(:test).to(:test2)
      
      r1.routes.size.should == r2.routes.size
      r1.url(:test).should == '/another'
      r2.url(:test).should == '/test2'
      
    end
  end
end