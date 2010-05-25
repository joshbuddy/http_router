describe "HttpRouter#generate" do
  before(:each) do
    @router = HttpRouter.new
  end

  context("static paths") do
    ['/', '/test', '/test/time', '/one/more/what', '/test.html'].each do |path|
      it "should generate #{path.inspect}" do
        route = @router.add(path)
        @router.url(route).should == path
      end
    end
  end

  context("dynamic paths") do
    it "should generate from a hash" do
      @router.add("/:var").name(:test)
      @router.url(:test, :var => 'test').should == '/test'
    end

    it "should generate from an array" do
      @router.add("/:var").name(:test)
      @router.url(:test, 'test').should == '/test'
    end

    it "should generate with a format" do
      @router.add("/test.:format").name(:test)
      @router.url(:test, 'html').should == '/test.html'
    end

    it "should generate with a format as a hash" do
      @router.add("/test.:format").name(:test)
      @router.url(:test, :format => 'html').should == '/test.html'
    end

    it "should generate with an optional format" do
      @router.add("/test(.:format)").name(:test)
      @router.url(:test, 'html').should == '/test.html'
      @router.url(:test).should == '/test'
    end

    context "with optional parts" do
      it "should generate both" do
        @router.add("/:var1(/:var2)").name(:test)
        @router.url(:test, 'var').should == '/var'
        @router.url(:test, 'var', 'fooz').should == '/var/fooz'
        @router.url(:test, :var1 => 'var').should == '/var'
        @router.url(:test, :var1 => 'var', :var2 => 'fooz').should == '/var/fooz'
        proc{@router.url(:test, :var2 => 'fooz').should == '/var/fooz'}.should raise_error(HttpRouter::UngeneratableRouteException)
      end
    end

  end
end
