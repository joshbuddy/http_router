describe "Rack interface extensions for Usher::Route" do
  before(:each) do
    @route_set = HttpRouter.new
    @app = MockApp.new("Hello World!")
    @env = Rack::MockRequest.env_for("/index.html")
  end

  describe "basic functinality" do
    it "should set redirect headers" do
      @route_set.get("/index.html").redirect("/")
      raw_response = @route_set.call(@env)
      response = Rack::MockResponse.new(*raw_response)
      response.should be_redirect
    end

    it "should redirect '/index.html' to '/'" do
      @route_set.get("/index.html").redirect("/")
      status, headers, body = @route_set.call(@env)
      headers["Location"].should eql("/")
    end

    it "should redirect '/:id.html' to '/:id'" do
      @route_set.get("/:id.html").redirect('/#{params[:id]}')
      @env = Rack::MockRequest.env_for("/123.html")
      status, headers, body = @route_set.call(@env)
      headers["Location"].should eql("/123")
    end
  end

  describe "static file serving" do
    it "should serve from a static directory" do
      @route_set.get("/static").static(File.dirname(__FILE__))
      @env = Rack::MockRequest.env_for("/static/#{File.basename(__FILE__)}")
      status, headers, body = @route_set.call(@env)
      body.path.should == File.join(File.dirname(__FILE__), File.basename(__FILE__))
    end

    it "should serve a specific file" do
      @route_set.get("/static-file").static(__FILE__)
      @env = Rack::MockRequest.env_for("/static-file")
      status, headers, body = @route_set.call(@env)
      body.path.should == __FILE__
    end
  end

  describe "chaining" do
    it "should be chainable" do
      @route_set.get("/index.html").redirect("/").name(:root)
      url = @route_set.url(:root)
      url.should eql("/index.html")
    end

    it "should not influence actual invoking" do
      @route_set.get("/index.html").redirect("/").name(:root)
      @route_set.call(@env)
    end
  end

  describe "custom status" do
    it "should enable to set custom HTTP status" do
      @route_set.get("/index.html").redirect("/", 303)
      status, headers, body = @route_set.call(@env)
      status.should eql(303)
    end

    it "should raise an exception if given HTTP code isn't a redirection" do
      lambda { @route_set.get("/index.html").redirect("/", 200) }.should raise_error(ArgumentError)
    end
  end
end
