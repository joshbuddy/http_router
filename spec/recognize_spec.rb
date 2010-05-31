describe "HttpRouter#recognize" do
  before(:each) do
    @router = HttpRouter.new
  end

  context("static paths") do
    ['/', '/test', '/test/time', '/one/more/what', '/test.html'].each do |path|
      it "should recognize #{path.inspect}" do
        route = @router.add(path).to(path)
        @router.recognize(Rack::MockRequest.env_for(path)).route.should == route
      end
    end

    context("with optional parts") do
      it "work either way" do
        route = @router.add("/test(/optional)").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test')).route.should == route
        @router.recognize(Rack::MockRequest.env_for('/test/optional')).route.should == route
      end
    end

    context("partial matching") do
      it "should match partially or completely" do
        route = @router.add("/test*").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test')).route.should == route
        response = @router.recognize(Rack::MockRequest.env_for('/test/optional'))
        response.route.should == route
        response.remaining_path.should == '/optional'
      end
    end

    context("proc acceptance") do
      it "should match optionally with a proc" do
        @router.add("/test").arbitrary(Proc.new{|req| req.host == 'hellodooly' }).to(:test1)
        @router.add("/test").arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 80}.to(:test2)
        @router.add("/test").arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 8080}.to(:test3)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8080/test'))
        response.dest.should == :test3
      end

      it "should still use an existing less specific node if possible" do
        @router.add("/test").to(:test4)
        @router.add("/test").arbitrary(Proc.new{|req| req.host == 'hellodooly' }).to(:test1)
        @router.add("/test").arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 80}.to(:test2)
        @router.add("/test").arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 8080}.to(:test3)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8081/test'))
        response.dest.should == :test4
      end

      it "should match optionally with a proc and request conditions" do
        @router.add("/test").get.arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 80}.to(:test1)
        @router.add("/test").get.arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 8080}.to(:test2)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8080/test'))
        response.dest.should == :test2
      end

      it "should still use an existing less specific node if possible with request conditions" do
        @router.add("/test").get.arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 80}.to(:test1)
        @router.add("/test").get.arbitrary(Proc.new{|req| req.host == 'lovelove' }).arbitrary{|req| req.port == 8080}.to(:test2)
        @router.add("/test").get.to(:test3)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8081/test'))
        response.dest.should == :test3
      end

    end

    context("trailing slashes") do
      it "should ignore a trailing slash" do
        route = @router.add("/test").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).route.should == route
      end

      it "should not recognize a trailing slash when used with the /? syntax and ignore_trailing_slash disabled" do
        @router = HttpRouter.new(:ignore_trailing_slash => false)
        route = @router.add("/test/?").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).route.should == route
      end

      it "should recognize a trailing slash when used with the /? syntax and ignore_trailing_slash enabled" do
        @router = HttpRouter.new(:ignore_trailing_slash => false)
        route = @router.add("/test").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).should be_nil
      end
      it "should not capture the trailing slash in a variable normally" do
        route = @router.add("/:test").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).params.first.should == 'test'
      end
    end

  end

  context "request methods" do
    it "should pick a specific request_method" do
      route = @router.post("/test").to(:test)
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'POST')).route.should == route
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'GET')).status.should == 405
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'GET')).headers['Allow'].should == "POST"
    end

    it "should pick a specific request_method with other paths all through it" do
      @router.post("/test").to(:test_post)
      @router.post("/test/post").to(:test_post_post)
      @router.get("/test").to(:test_get)
      @router.get("/test/post").to(:test_post_get)
      @router.add("/test/post").to(:test_post_catchall)
      @router.add("/test").to(:test_catchall)
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'POST')).dest.should == :test_post
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'GET')).dest.should == :test_get
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'PUT')).dest.should == :test_catchall
      @router.recognize(Rack::MockRequest.env_for('/test/post', :method => 'POST')).dest.should == :test_post_post
      @router.recognize(Rack::MockRequest.env_for('/test/post', :method => 'GET')).dest.should == :test_post_get
      @router.recognize(Rack::MockRequest.env_for('/test/post', :method => 'PUT')).dest.should == :test_post_catchall
    end

    it "should move an endpoint to the non-specific request method when a more specific route gets added" do
      @router.add("/test").name(:test_catchall).to(:test1)
      @router.post("/test").name(:test_post).to(:test2)
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'POST')).route.named.should == :test_post
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'PUT')).route.named.should == :test_catchall
    end

    it "should try both specific and non-specifc routes" do
      @router.post("/test").host('host1').to(:post_host1)
      @router.add("/test").host('host2').to(:any_post2)
      @router.recognize(Rack::MockRequest.env_for('http://host2/test', :method => 'POST')).dest.should == :any_post2
    end

  end

  context("dynamic paths") do
    it "should recognize '/:variable'" do
      route = @router.add('/:variable').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/value'))
      response.route.should == route
      response.params.should == ['value']
      response.params_as_hash[:variable].should == 'value'
    end

    it "should recognize '/test.:format'" do
      route = @router.add('/test.:format').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/test.html'))
      response.route.should == route
      response.params_as_hash[:format].should == 'html'
      @router.recognize(Rack::MockRequest.env_for('/test')).should be_nil
    end

    it "should recognize '/test(.:format)'" do
      route = @router.add('/test(.:format)').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/test.html'))
      response.route.should == route
      response.params_as_hash[:format].should == 'html'
      response = @router.recognize(Rack::MockRequest.env_for('/test'))
      response.route.should == route
      response.params_as_hash[:format].should be_nil
    end

    it "should recognize '/:test.:format'" do
      route = @router.add('/:test.:format').compile.to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/hey.html'))
      response.route.should == route
      response.params_as_hash[:format].should == 'html'
      response.params_as_hash[:test].should == 'hey'
    end

    it "should recognize '/:test(.:format)'" do
      route = @router.add('/:test(.:format)').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/hey.html'))
      response.route.should == route
      response.params_as_hash[:format].should == 'html'
      response.params_as_hash[:test].should == 'hey'
      response = @router.recognize(Rack::MockRequest.env_for('/hey'))
      response.route.should == route
      response.params_as_hash[:format].should be_nil
      response.params_as_hash[:test].should == 'hey'
    end
    
    context "globs" do
      it "should recognize a glob" do
        route = @router.add('/test/*variable').to(:test)
        response = @router.recognize(Rack::MockRequest.env_for('/test/one/two/three'))
        response.route.should == route
        response.params.should == [['one', 'two', 'three']]
      end
      it "should recognize a glob with a regexp" do
        route = @router.add('/test/*variable/anymore').matching(:variable => /^\d+$/).to(:test)
        response = @router.recognize(Rack::MockRequest.env_for('/test/123/345/567/anymore'))
        response.route.should == route
        response.params.should == [['123', '345', '567']]
        response = @router.recognize(Rack::MockRequest.env_for('/test/123/345/567'))
        response.should be_nil
      end
    end
    
  end
  
  context("interstitial variables") do
    it "should recognize interstitial variables" do
      route = @router.add('/one-:variable-time').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/one-value-time'))
      response.route.should == route
      response.params_as_hash[:variable].should == 'value'
    end

    it "should recognize interstitial variables with a regex" do
      route = @router.add('/one-:variable-time').matching(:variable => /^\d+/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/one-value-time')).should be_nil
      response = @router.recognize(Rack::MockRequest.env_for('/one-123-time'))
      response.route.should == route
      response.params_as_hash[:variable].should == '123'
    end
    
    it "should recognize interstitial variable when there is an extension" do
      route = @router.add('/hey.:greed.html').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/hey.greedyboy.html'))
      response.route.should == route
      response.params_as_hash[:greed].should == 'greedyboy'
    end
    
  end

  context("dynamic greedy paths") do
    it "should recognize greedy variables" do
      route = @router.add('/:variable').matching(:variable => /\d+/).to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/123'))
      response.route.should == route
      response.params.should == ['123']
      response.params_as_hash[:variable].should == '123'
      response = @router.recognize(Rack::MockRequest.env_for('/asd'))
      response.should be_nil
    end

    it "should capture the trailing slash in a greedy variable" do
      route = @router.add("/:test").matching(:test => /.*/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/test/')).params.first.should == 'test/'
    end

    it "should capture the extension in a greedy variable" do
      route = @router.add("/:test").matching(:test => /.*/).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/test.html')).params.first.should == 'test.html'
    end

  end
end
