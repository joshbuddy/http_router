describe "HttpRouter#generate" do
  before(:each) do
    @router = HttpRouter.new
  end

  context("static paths") do
    ['/', '/test', '/test/time', '/one/more/what', '/test.html'].each do |path|
      it "should generate #{path.inspect}" do
        route = @router.add(path).compile
        @router.url(route).should == path
      end
    end
  end

  context("dynamic paths") do
    it "should generate from a hash" do
      @router.add("/:var").name(:test).compile
      @router.url(:test, :var => 'test').should == '/test'
    end

    it "should generate from a hash with extra parts going to the query string" do
      @router.add("/:var").name(:test).compile
      @router.url(:test, :var => 'test', :query => 'string').should == '/test?query=string'
    end

    it "should generate from an array" do
      @router.add("/:var").name(:test).compile
      @router.url(:test, 'test').should == '/test'
    end

    it "should generate from an array with extra parts going to the query string" do
      @router.add("/:var").name(:test).compile
      @router.url(:test, 'test', :query => 'string').should == '/test?query=string'
    end
    
    it "should generate with multiple dynamics" do
      @router.add("/:var/:baz").name(:test).compile
      @router.url(:test, 'one', 'two').should == '/one/two'
      @router.url(:test, :var => 'one', :baz => 'two').should == '/one/two'
    end

    context "with a :format" do
      it "should generate with a format" do
        @router.add("/test.:format").name(:test).compile
        @router.url(:test, 'html').should == '/test.html'
      end

      it "should generate with a format as a hash" do
        @router.add("/test.:format").name(:test).compile
        @router.url(:test, :format => 'html').should == '/test.html'
      end
      
      it "should generate with format as a symbol" do
        @router.add("/test.:format").name(:test).compile
        @router.url(:test, :format => :html).should == '/test.html'
      end

      it "should generate with an optional format" do
        @router.add("/test(.:format)").name(:test).compile
        @router.url(:test, 'html').should == '/test.html'
        @router.url(:test).should == '/test'
      end
      
      it "should generate a dynamic path and a format" do
        @router.add("/:var1.:format").name(:test).compile
        @router.url(:test, 'var', :format => 'html').should == '/var.html'
      end
      
      it "should generate a dynamic path and an optional format" do
        @router.add("/:var1(.:format)").name(:test).compile
        @router.url(:test, 'var').should == '/var'
        @router.url(:test, 'var', :format => 'html').should == '/var.html'
      end
      
      it "should generate multiple dynamics and a format" do
        @router.add("/:foo/:bar.:format").name(:test).compile
        @router.url(:test, 'var', 'baz', 'html').should == '/var/baz.html'
        @router.url(:test, :foo => 'var', :bar => 'baz', :format => 'html').should == '/var/baz.html'
      end
      
      it "should generate multiple dynamics and an optional format" do
        @router.add("/:foo/:bar(.:format)").name(:test).compile
        @router.url(:test, 'var', 'baz').should == '/var/baz'
        @router.url(:test, 'var', 'baz', 'html').should == '/var/baz.html'
        @router.url(:test, :foo => 'var', :bar => 'baz').should == '/var/baz'
        @router.url(:test, :foo => 'var', :bar => 'baz', :format => 'html').should == '/var/baz.html'
      end
    end

    context "with optional parts" do
      it "should generate both" do
        @router.add("/:var1(/:var2)").name(:test).compile
        @router.url(:test, 'var').should == '/var'
        @router.url(:test, 'var', 'fooz').should == '/var/fooz'
        @router.url(:test, :var1 => 'var').should == '/var'
        @router.url(:test, :var1 => 'var', :var2 => 'fooz').should == '/var/fooz'
        proc{@router.url(:test, :var2 => 'fooz').should == '/var/fooz'}.should raise_error(HttpRouter::UngeneratableRouteException)
      end
      it "should generate with a format" do
        @router.add("/:var1(/:var2.:format)").name(:test).compile
        @router.url(:test, 'var').should == '/var'
        @router.url(:test, 'var', 'fooz', 'html').should == '/var/fooz.html'
        @router.url(:test, :var1 => 'var').should == '/var'
        @router.url(:test, :var1 => 'var', :var2 => 'fooz', :format => 'html').should == '/var/fooz.html'
      end
      it "should generate with an embeded optional" do
        @router.add("/:var1(/:var2(/:var3))").name(:test).compile
        @router.url(:test, 'var').should == '/var'
        @router.url(:test, 'var', 'fooz').should == '/var/fooz'
        @router.url(:test, 'var', 'fooz', 'baz').should == '/var/fooz/baz'
        @router.url(:test, :var1 => 'var').should == '/var'
        @router.url(:test, :var1 => 'var', :var2 => 'fooz', :var3 => 'baz').should == '/var/fooz/baz'
      end

      it "should support optional plus optional format" do
        @router.add("/:var1(/:var2)(.:format)").name(:test).compile
        @router.url(:test, 'var').should == '/var'
        @router.url(:test, 'var', 'fooz').should == '/var/fooz'
        @router.url(:test, 'var', 'fooz', 'html').should == '/var/fooz.html'
        @router.url(:test, :var1 => 'var').should == '/var'
        @router.url(:test, :var1 => 'var', :var2 => 'fooz', :format => 'html').should == '/var/fooz.html'
        @router.url(:test, :var1 => 'var', :format => 'html').should == '/var.html'
      end
    end
    
  end
end
