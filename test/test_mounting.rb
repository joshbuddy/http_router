class TestMounting < MiniTest::Unit::TestCase
  def setup
    @r1 = HttpRouter.new
    @r2 = HttpRouter.new
    @r2.add("/bar").name(:test).compile
  end

  def test_url_mount_for_child_route
    route = @r1.add("/foo").to(@r2)
    assert_equal "/foo", @r2.url_mount.url
    assert_equal "/foo/bar", @r2.url(:test)
  end

  def test_default_values
    route = @r1.add("/foo/:bar").default(:bar => "baz").to(@r2)
    assert_equal "/foo/baz/bar", @r2.url(:test)
    assert_equal "/foo/haha/bar", @r2.url(:test, :bar => "haha")
  end

  def test_multiple_values
    @r1.add("/foo/:bar/:baz").default(:bar => "bar").to(@r2)
    assert_equal "/foo/bar/baz/bar", @r2.url(:test, :baz => "baz")
  end
  
  def test_bubble_params
    route = @r1.add("/foo/:bar").default(:bar => "baz").to(@r2)
    assert_equal "/foo/baz/bar?bang=ers",  @r2.url(:test, :bang => "ers")
    assert_equal "/foo/haha/bar?bang=ers", @r2.url(:test, :bar => "haha", :bang => "ers")
  end

  def test_path_with_optional
    @r1.add("/foo(/:bar)").to(@r2)
    @r2.add("/hey(/:there)").name(:test).compile
    assert_equal "/foo/hey", @r2.url(:test)
    assert_equal "/foo/bar/hey", @r2.url(:test, :bar => "bar")
    assert_equal "/foo/bar/hey/there", @r2.url(:test, :bar => "bar", :there => "there")
  end

  def test_nest3
    @r3 = HttpRouter.new
    @r1.add("/foo(/:bar)").default(:bar => "barry").to(@r2)
    @r2.add("/hi").name(:hi).compile
    @r2.add("/mounted").to(@r3)
    @r3.add("/endpoint").name(:endpoint).compile
    
    assert_equal "/foo/barry/hi",                @r2.url(:hi)
    assert_equal "/foo/barry/mounted/endpoint",  @r3.url(:endpoint)
    assert_equal "/foo/flower/mounted/endpoint", @r3.url(:endpoint, :bar => "flower")
  end

  def test_with_default_host
    @r1.add("/mounted").default(:host => "example.com").to(@r2)
    assert_equal "http://example.com/mounted/bar", @r2.url(:test)
  end

  def test_with_host
    @r1.add("/mounted").to(@r2)
    assert_equal "/mounted/bar", @r2.url(:test)
    assert_equal "http://example.com/mounted/bar", @r2.url(:test, :host => "example.com")
  end

  def test_with_scheme
    @r1.add("/mounted").to(@r2)
    assert_equal "/mounted/bar", @r2.url(:test)
    assert_equal "https://example.com/mounted/bar", @r2.url(:test, :scheme => "https", :host => "example.com")
  end
end

#      it "should clone my nested structure" do
#        @r3 = HttpRouter.new
#        @r1.add("/first").to(@r2)
#        @r2.add("/second").to(@r3)
#        r1 = @r1.clone
#        @r1.routes.first.should_not be_nil
#        r2 = r1.routes.first.dest
#        r2.should_not be_nil
#        @r1.routes.first.dest.object_id.should == @r2.object_id
#        r2.object_id.should_not == @r2.object_id
#        r2.routes.should have(2).route
#        r3 = r2.routes.last.dest
#        r3.should be_an_instance_of(HttpRouter)
#        r3.object_id.should_not == @r3.object_id
#      end
#    end
#  end
#end
