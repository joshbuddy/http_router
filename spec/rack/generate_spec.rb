route_set = HttpRouter.new
route_set.extend(CallWithMockRequestMixin)

describe "Usher (for rack) route generation" do
  before(:each) do
    route_set.reset!
    @app = MockApp.new("Hello World!")
    route_set.add("/fixed").name(:fixed).compile
    route_set.add("/named/simple/:named_simple_var").name(:simple).compile
    route_set.add("/named/optional(/:named_optional_var)").name(:optional).compile
  end
  
  describe "named routes" do
    it "should generate a fixed path" do
      route_set.url(:fixed).should == "/fixed"
    end
    
    it "should generate a named path route" do
      route_set.url(:simple, :named_simple_var => "the_var").should == "/named/simple/the_var"
    end

    it "should generate a named route with options" do
      route_set.url(:optional).should == "/named/optional"
      route_set.url(:optional, :named_optional_var => "the_var").should == "/named/optional/the_var"
    end
  end
end
