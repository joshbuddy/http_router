require 'spec_helper'
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

    context "with default values" do
      it "should generate with all params" do
        @router.add("/:var").default(:page => 1).name(:test).compile
        @router.url(:test, 123).should == "/123?page=1"
      end
    end

    context "with a matching" do
      it "should raise an exception when the route is invalid" do
        @router.add("/:var").matching(:var => /\d+/).name(:test).compile
        proc{@router.url(:test, 'asd')}.should raise_error(HttpRouter::InvalidRouteException)
      end
    end

    context "url mounting" do
      context "nested routes" do
        before(:each) do
          @r1 = HttpRouter.new
          @r2 = HttpRouter.new
          @r2.add("/bar").name(:test).compile
        end

        it "should set the url mount on a child route" do
          route = @r1.add("/foo").to(@r2)
          @r2.url_mount.url.should == "/foo"
          @r2.url(:test).should == "/foo/bar"
        end

        it "should set any default values on the url mount" do
          route = @r1.add("/foo/:bar").default(:bar => "baz").to(@r2)
          @r2.url(:test).should == "/foo/baz/bar"
          @r2.url(:test, :bar => "haha").should == "/foo/haha/bar"
        end

        it "should use multiple variables" do
          @r1.add("/foo/:bar/:baz").default(:bar => "bar").to(@r2)
          @r2.url(:test, :baz => "baz").should == "/foo/bar/baz/bar"
        end

        it "should not steal parameters from the defaults it doesn't need" do
          route = @r1.add("/foo/:bar").default(:bar => "baz").to(@r2)
          @r2.url(:test, :bang => "ers").should == "/foo/baz/bar?bang=ers"
          @r2.url(:test, :bar => "haha", :bang => "ers").should == "/foo/haha/bar?bang=ers"
        end

        it "should generate on a path with an optional variable" do
          @r1.add("/foo(/:bar)").to(@r2)
          @r2.add("/hey(/:there)").name(:test).compile
          @r2.url(:test).should == "/foo/hey"
          @r2.url(:test, :bar => "bar").should == "/foo/bar/hey"
          @r2.url(:test, :bar => "bar", :there => "there").should == "/foo/bar/hey/there"
        end

        it "should nest 3 times deeply" do
          @r3 = HttpRouter.new
          @r1.add("/foo(/:bar)").default(:bar => "barry").to(@r2)
          @r2.add("/hi").name(:hi).compile
          @r2.add("/mounted").to(@r3)
          @r3.add("/endpoint").name(:endpoint).compile

          @r2.url(:hi).should == "/foo/barry/hi"
          @r3.url(:endpoint).should == "/foo/barry/mounted/endpoint"
          @r3.url(:endpoint, :bar => "flower").should == "/foo/flower/mounted/endpoint"
        end

        it "should allow me to set the host via a default" do
          @r1.add("/mounted").default(:host => "example.com").to(@r2)
          @r2.url(:test).should == "http://example.com/mounted/bar"
        end

        it "should allow me to set the host via an option" do
          @r1.add("/mounted").to(@r2)
          @r2.url(:test).should == "/mounted/bar"
          @r2.url(:test, :host => "example.com").should == "http://example.com/mounted/bar"
        end

        it "should allow me to set the scheme via an option" do
          @r1.add("/mounted").to(@r2)
          @r2.url(:test).should == "/mounted/bar"
          @r2.url(:test, :scheme => "https", :host => "example.com").should == "https://example.com/mounted/bar"
        end

        it "should clone my nested structure" do
          @r3 = HttpRouter.new
          @r1.add("/first").to(@r2)
          @r2.add("/second").to(@r3)
          r1 = @r1.clone
          @r1.routes.first.should_not be_nil
          r2 = r1.routes.first.dest
          r2.should_not be_nil
          @r1.routes.first.dest.object_id.should == @r2.object_id
          r2.object_id.should_not == @r2.object_id
          r2.routes.should have(2).route
          r3 = r2.routes.last.dest
          r3.should be_an_instance_of(HttpRouter)
          r3.object_id.should_not == @r3.object_id
        end
      end
    end
  end
end
