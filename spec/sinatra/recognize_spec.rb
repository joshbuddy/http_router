require 'spec_helper'
require "sinatra"
require "http_router/interface/sinatra"

describe "HttpRouter (for Sinatra) route recognition" do
  before(:each) do
    @app = Sinatra.new { register HttpRouter::Interface::Sinatra::Extension }
    @app.extend(CallWithMockRequestMixin)
    @app.reset!
  end

  describe "basic functionality" do
    it "should map not found" do
      response = @app.call_with_mock_request('/bar')
      response.status.should == 404
    end

    it "should map index" do
      @app.get("/") { "index" }
      response = @app.call_with_mock_request('/')
      response.status.should == 200
      response.body.should == "index"
    end

    it "should ignore trailing delimiters" do
      @app.get("/foo") { "foo" }
      response = @app.call_with_mock_request('/foo')
      response.status.should == 200
      response.body.should == "foo"
      response = @app.call_with_mock_request('/foo/')
      response.status.should == 200
      response.body.should == "foo"
    end

    it "should ignore trailing delimiters in a more advanced route" do
      @app.get("/foo") { "foo" }
      @app.get("/foo/bar") { "bar" }
      response = @app.call_with_mock_request('/foo')
      response.status.should == 200
      response.body.should == "foo"
      response = @app.call_with_mock_request('/foo/bar')
      response.status.should == 200
      response.body.should == "bar"
      response = @app.call_with_mock_request('/foo/')
      response.status.should == 200
      response.body.should == "foo"
      response = @app.call_with_mock_request('/foo/bar/')
      response.status.should == 200
      response.body.should == "bar"
    end

    it "should ignore trailing delimiters with an optional param" do
      @app.get("/foo/(:bar)") { params[:bar] }
      @app.get("/bar(/:foo)") { params[:foo] }
      response = @app.call_with_mock_request('/foo/bar')
      response.status.should == 200
      response.body.should == "bar"
      response = @app.call_with_mock_request('/bar/foo')
      response.status.should == 200
      response.body.should == "foo"
      response = @app.call_with_mock_request('/bar')
      response.status.should == 200
      response.body.should == ""
      response = @app.call_with_mock_request('/bar/')
      response.status.should == 200
      response.body.should == ""
    end

    it "should use sinatra optionals trailing delimiters" do
      @app.get("/foo/?") { "foo" }
      response = @app.call_with_mock_request('/foo')
      response.status.should == 200
      response.body.should == "foo"
      response = @app.call_with_mock_request('/foo/')
      response.status.should == 200
      response.body.should == "foo"
    end
  end

  describe "mapping functionality" do

    it "should map a basic route" do
      @app.get('/hi', :name => :hi) { generate(:hi) }
      response = @app.call_with_mock_request('/hi')
      response.status.should == 200
      response.body.should == "/hi"
    end

    it "should map a basic route ignoring trailing delimiters" do
      @app.get('/hi', :name => :hi) { generate(:hi) }
      response = @app.call_with_mock_request('/hi/')
      response.status.should == 200
      response.body.should == "/hi"
    end

    it "should map a basic route with params" do
      @app.get('/hi/:id', :name => :hi) { generate(:hi, :id => 18) }
      response = @app.call_with_mock_request('/hi/1')
      response.status.should == 200
      response.body.should == "/hi/18"
    end

    it "should map route with params" do
      @app.get('/hi-:id', :name => :hi) { generate(:hi, :id => 18) }
      response = @app.call_with_mock_request('/hi-1')
      response.status.should == 200
      response.body.should == "/hi-18"
    end

    it "should map route with complex params" do
      @app.get('/hi/:foo/:bar/:baz(.:format)') { "/#{params[:foo]}/#{params[:bar]}/#{params[:baz]}/#{params[:format]}" }
      response = @app.call_with_mock_request('/hi/foo/bar/baz')
      response.status.should == 200
      response.body.should == "/foo/bar/baz/"
      response = @app.call_with_mock_request('/hi/foo/bar-bax/baz')
      response.status.should == 200
      response.body.should == "/foo/bar-bax/baz/"
    end
  end

  describe "matching by regexp" do
    before :each do
      @app.get('/numbers/:digits', :matching => { :digits => /\d+/ }) { params[:digits] }
    end

    describe "when regexp is matched" do
      before :each do
        @response = @app.call_with_mock_request('/numbers/2010')
      end

      it "should map successfully" do
        @response.status.should == 200
        @response.body.should == "2010"
      end
    end

    describe "when regexp is not matched" do
      before :each do
        @response = @app.call_with_mock_request('/numbers/boobs')
      end

      it "should not map" do
        @response.status.should == 404
      end
    end
  end

  describe "not found" do

    it "should correctly generate a not found page without images" do
      response = @app.call_with_mock_request('/bar')
      response.status.should == 404
      response.body.should_not match(/__sinatra__/)
    end
  end

  describe "method not allowed" do

    it "should correctly generate a not found page without images and return a 405" do
      @app.post('/bar') { 'found' }
      @app.put('/bar') { 'found' }
      response = @app.call_with_mock_request('/bar')
      response.status.should == 405
      response.headers['Allow'].should == 'POST, PUT'
      response.body.should_not match(/__sinatra__/)
    end
  end
end
