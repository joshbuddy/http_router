require 'spec_helper'
describe "HttpRouter#recognize" do
  before(:each) do
    @router = HttpRouter.new
  end

  context("with interstitial variables") do
    it "should recognize" do
      route = @router.add('/one-:variable-time').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/one-value-time'))
      response.route.should == route
      response.params_as_hash[:variable].should == 'value'
    end

    it "should recognize with a regex" do
      route = @router.add('/one-:variable-time').matching(:variable => /\d+/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/one-value-time')).should be_nil
      response = @router.recognize(Rack::MockRequest.env_for('/one-123-time'))
      response.route.should == route
      response.params_as_hash[:variable].should == '123'
    end

    it "should recognize with a regex as part of the options" do
      route = @router.add('/one-:variable-time', :variable => /\d+/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/one-value-time')).should be_nil
      response = @router.recognize(Rack::MockRequest.env_for('/one-123-time'))
      response.route.should == route
      response.params_as_hash[:variable].should == '123'
    end

    it "should recognize when there is an extension" do
      route = @router.add('/hey.:greed.html').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/hey.greedyboy.html'))
      response.route.should == route
      response.params_as_hash[:greed].should == 'greedyboy'
    end

    it "should distinguish between very similar looking routes" do
      @router.add('/:var1').to(:test1)
      @router.add('/:var1-:var2').to(:test2)
      @router.add('/:var1-:var2-:var3').to(:test3)
      @router.add('/:var1-:var2-:var3-:var4').to(:test4)
      @router.add('/:var1-:var2-:var3-:var4-:var5').to(:test5)
      @router.add('/:var1-:var2-:var3-:var4-:var5-:var6').to(:test6)
      @router.recognize(Rack::MockRequest.env_for('/one')).dest.should == :test1
      @router.recognize(Rack::MockRequest.env_for('/one-value')).dest.should == :test2
      @router.recognize(Rack::MockRequest.env_for('/one-value-time')).dest.should == :test3
      @router.recognize(Rack::MockRequest.env_for('/one-value-time-one')).dest.should == :test4
      @router.recognize(Rack::MockRequest.env_for('/one-value-time-one-variable')).dest.should == :test5
      @router.recognize(Rack::MockRequest.env_for('/one-value-time-one-value-time')).dest.should == :test6
    end
  end

  context("with dynamic greedy paths") do
    it "should recognize" do
      route = @router.add('/:variable').matching(:variable => /\d+/).to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/123'))
      response.route.should == route
      response.params.should == ['123']
      response.params_as_hash[:variable].should == '123'
      response = @router.recognize(Rack::MockRequest.env_for('/asd'))
      response.should be_nil
    end

    it "should continue on with normal if regex fails to match" do
      @router.add("/:test/number").matching(:test => /\d+/).to(:test_number)
      target = @router.add("/:test/anything").to(:test_anything)
      @router.recognize(Rack::MockRequest.env_for('/123/anything')).route.should == target
    end

    it "should capture the trailing slash" do
      route = @router.add("/:test").matching(:test => /.*/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/test/')).params.first.should == 'test/'
    end

    it "should require the match to begin at the beginning" do
      route = @router.add("/:test").matching(:test => /\d+/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/a123')).should be_nil
    end

    it "should capture the extension" do
      route = @router.add("/:test").matching(:test => /.*/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/test.html')).params.first.should == 'test.html'
    end

    # BUG: http://gist.github.com/554909
    context "when there is an additional route for the case of regex matching failure" do
      before :each do
        @matched = @router.add("/:common_variable/:matched").matching(:matched => /\d+/).to(:something)
        @unmatched = @router.add("/:common_variable/:unmatched").to(:something_unmatched)
      end

      it "should use main route if pattern is matched" do
        response = @router.recognize(Rack::MockRequest.env_for('/common/123'))
        response.route.should == @matched
        response.params.should == ['common', '123']
      end

      it "should use additional route if pattern is not matched" do
        response = @router.recognize(Rack::MockRequest.env_for('/common/other'))
        response.route.should == @unmatched
        response.params.should == ['common', 'other']
      end

      context "when delimiter is not a slash" do
        before :each do
          @matched = @router.add("/:common_variable.:matched").matching(:matched => /\d+/).to(:something)
          @unmatched = @router.add("/:common_variable.:unmatched").to(:something_unmatched)
        end

        it "should use main route if pattern is matched" do
          response = @router.recognize(Rack::MockRequest.env_for('/common.123'))
          response.route.should == @matched
          response.params.should == ['common', '123']
        end

        it "should use additional route if pattern is not matched" do
          response = @router.recognize(Rack::MockRequest.env_for('/common.other'))
          response.route.should == @unmatched
          response.params.should == ['common', 'other']
        end
      end
    end
  end
end
