route_set = HttpRouter.new
route_set.extend(CallWithMockRequestMixin)

describe "HttpRouter route dispatching with redirect_on_trailing_delimiters" do
  before(:each) do
    @route_set = HttpRouter.new(:redirect_trailing_slash => true)
    @route_set.extend(CallWithMockRequestMixin)
    @app = MockApp.new("Hello World!")
    @route_set.add('/sample').to(@app)
  end

  it "should dispatch a request" do
    response = @route_set.call_with_mock_request('/sample/')
    response.headers["Location"].should == "/sample"
  end

end

describe "HttpRouter route dispatching" do
  before(:each) do
    route_set.reset!
    @app = MockApp.new("Hello World!")
  end

  describe "HTTP GET" do
    before(:each) do
      route_set.reset!
      route_set.add('/sample').request_method('GET').to(@app)
    end

    it "should dispatch a request" do
      response = route_set.call_with_mock_request
      response.body.should eql("Hello World!")
    end

    it "should write router.params" do
      response = route_set.call_with_mock_request
      @app.env["router.params"].should == {}
    end
  end

  describe "HTTP POST" do
    before(:each) do
      route_set.reset!
      route_set.add('/sample').post.to(@app)
      route_set.add('/sample').to(MockApp.new("You shouldn't get here if you are using POST"))
    end

    it "should dispatch a POST request" do
      response = route_set.call_with_mock_request('/sample', 'POST')
      response.body.should eql("Hello World!")
    end

    it "shouldn't dispatch a GET request" do
      response = route_set.call_with_mock_request('/sample', 'GET')
      response.body.should eql("You shouldn't get here if you are using POST")
    end

    it "should write router.params" do
      response = route_set.call_with_mock_request("/sample", 'POST')
      @app.env["router.params"].should == {}
    end
  end

  it "should returns HTTP 405 if the method mis-matches" do
    route_set.reset!
    route_set.post('/sample').to(@app)
    route_set.put('/sample').to(@app)
    response = route_set.call_with_mock_request('/sample', 'GET')
    response.status.should eql(405)
    response['Allow'].should == 'POST, PUT'
  end

  it "should returns HTTP 404 if route doesn't exist" do
    response = route_set.call_with_mock_request("/not-existing-url")
    response.status.should eql(404)
  end

  describe "shortcuts" do
    describe "get" do
      before(:each) do
        route_set.reset!
        route_set.get('/sample').head.to(@app)
      end

      it "should dispatch a GET request" do
        response = route_set.call_with_mock_request("/sample", "GET")
        response.body.should eql("Hello World!")
      end

      it "should dispatch a HEAD request" do
        response = route_set.call_with_mock_request("/sample", "HEAD")
        response.body.should eql("Hello World!")
      end
    end
  end

  describe "non rack app destinations" do
    it "should route to a default application when using a hash" do
      $captures = []
      @default_app = lambda do |e|
        $captures << :default
        Rack::Response.new("Default").finish
      end
      @router = HttpRouter.new
      @router.default(@default_app)
      @router.add("/default").to(:action => "default")
      response = @router.call(Rack::MockRequest.env_for("/default"))
      $captures.should == [:default]
    end
  end

end
