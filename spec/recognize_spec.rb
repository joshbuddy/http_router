require 'spec_helper'
describe "HttpRouter#recognize" do
  before(:each) do
    @router = HttpRouter.new
  end

  context("with static paths") do
    ['/', '/test', '/test/time', '/one/more/what', '/test.html', '/.html'].each do |path|
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

    context("with escaping") do
      it "should recognize ()" do
        route = @router.add('/test\(:variable\)').to(:test)
        response = @router.recognize(Rack::MockRequest.env_for('/test(hello)'))
        response.route.should == route
        response.params.first.should == 'hello'
      end

      it "should recognize :" do
        route = @router.add('/test\:variable').to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test:variable')).dest.should == :test
      end

      it "should recognize *" do
        route = @router.add('/test\*variable').to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test*variable')).dest.should == :test
      end
    end

    context("with partial matching") do
      before(:each) do
        route = @router.add("/test*").to{|env| []}
      end
      
      it "should match partially" do
        route = @router.add("/test*").to{|env| env['PATH_INFO'].should == '/optional'; [200, {}, []]}
        response = @router.call(Rack::MockRequest.env_for('/test/optional'))
        response[0].should == 200
      end

      it "should match partially and use / for rest if the route matched completely" do
        route = @router.add("/test*").to{|env| env['PATH_INFO'].should == '/'; [200, {}, []]}
        response = @router.call(Rack::MockRequest.env_for('/test'))
        response[0].should == 200
      end

    end

    context("with multiple partial matching") do
      it "should match partially" do
        @router.add("/test").partial.to{|env| [200, {}, ['/test',env['PATH_INFO']]]}
        @router.add("/").partial.to{|env| [200, {}, ['/',env['PATH_INFO']]]}
        @router.call(Rack::MockRequest.env_for('/test/optional')).last.should == ['/test', '/optional']
        @router.call(Rack::MockRequest.env_for('/testing/optional')).last.should == ['/', '/testing/optional']
      end
    end


    context("with proc acceptance") do
      it "should match" do
        @router.add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'hellodooly' }).to(:test1)
        @router.add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}.to(:test2)
        @router.add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}.to(:test3)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8080/test'))
        response.dest.should == :test3
      end

      it "should still use an existing less specific node if possible" do
        @router.add("/test").to(:test4)
        @router.add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'hellodooly' }).to(:test1)
        @router.add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}.to(:test2)
        @router.add("/test").arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}.to(:test3)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8081/test'))
        response.dest.should == :test4
      end

      it "should match with request conditions" do
        @router.add("/test").get.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}.to(:test1)
        @router.add("/test").get.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}.to(:test2)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8080/test'))
        response.dest.should == :test2
      end

      it "should still use an existing less specific node if possible with request conditions" do
        @router.add("/test").get.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 80}.to(:test1)
        @router.add("/test").get.arbitrary(Proc.new{|req, params, dest| req.host == 'lovelove' }).arbitrary{|req, params, dest| req.port == 8080}.to(:test2)
        @router.add("/test").get.to(:test3)
        response = @router.recognize(Rack::MockRequest.env_for('http://lovelove:8081/test'))
        response.dest.should == :test3
      end

      it "should pass params and dest" do
        @router.add("/:test").get.arbitrary(Proc.new{|req, params, dest| params[:test] == 'test' and dest == :test1 }).to(:test1)
        response = @router.recognize(Rack::MockRequest.env_for('/test'))
        response.dest.should == :test1
      end
    end

    context("with trailing slashes") do
      it "should ignore" do
        route = @router.add("/test").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).route.should == route
      end

      it "should not recognize when used with the /? syntax and ignore_trailing_slash disabled" do
        @router = HttpRouter.new(:ignore_trailing_slash => false)
        route = @router.add("/test/?").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).route.should == route
      end

      it "should recognize when used with the /? syntax and ignore_trailing_slash enabled" do
        @router = HttpRouter.new(:ignore_trailing_slash => false)
        route = @router.add("/test").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).should be_nil
      end

      it "should not capture normally" do
        route = @router.add("/:test").to(:test)
        @router.recognize(Rack::MockRequest.env_for('/test/')).params.first.should == 'test'
      end
      
      it "should recognize trailing slashes when there are other more specific routes near by" do
        @router = HttpRouter.new
        route = @router.add("/foo").to(:foo)
        route = @router.add("/foo/:bar/:id").to(:foo_bar)
        @router.recognize(Rack::MockRequest.env_for('/foo')).dest.should == :foo
        @router.recognize(Rack::MockRequest.env_for('/foo/')).dest.should == :foo
        @router.recognize(Rack::MockRequest.env_for('/foo/5/10')).dest.should == :foo_bar
      end
    end
  end

  context "with missing leading /" do
    it "should recognize" do
      @router.add("foo").to(:test1)
      @router.add("foo.html").to(:test2)
      @router.recognize(Rack::MockRequest.env_for('/foo')).dest.should == :test1
      @router.recognize(Rack::MockRequest.env_for('/foo.html')).dest.should == :test2
    end
  end

  context "with request methods" do
    it "should recognize" do
      route = @router.post("/test").to(:test)
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'POST')).route.should == route
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'GET')).status.should == 405
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'GET')).headers['Allow'].should == "POST"
    end

    it "should recognize with optional parts and correctly return a 405 when the method isn't found" do
      @router.get("/test(.:format)").to(:get)
      @router.post("/test(.:format)").to(:post)
      @router.delete("/test(.:format)").to(:delete)
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'POST')).destination.should == :post
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'GET')).destination.should == :get
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'DELETE')).destination.should == :delete
      @router.recognize(Rack::MockRequest.env_for('/test', :method => 'PUT')).status.should == 405
      methods = @router.recognize(Rack::MockRequest.env_for('/test', :method => 'PUT')).headers['Allow'].split(/,\s+/)
      methods.should include('DELETE')
      methods.should include('GET')
      methods.should include('POST')
      methods.size.should == 3
      @router.recognize(Rack::MockRequest.env_for('/test.html', :method => 'POST')).destination.should == :post
      @router.recognize(Rack::MockRequest.env_for('/test.html', :method => 'GET')).destination.should == :get
      @router.recognize(Rack::MockRequest.env_for('/test.html', :method => 'DELETE')).destination.should == :delete
      @router.recognize(Rack::MockRequest.env_for('/test.html', :method => 'PUT')).status.should == 405
    end

    it "should recognize deeply" do
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

    it "should try multiple request method restrictions in both orders" do
      @router.add("/test").host('host2').to(:host2)
      @router.add("/test").post.to(:post)
      @router.add("/test").host('host2').get.to(:host2_get)
      @router.add("/test").post.host('host2').to(:host2_post)

      @router.recognize(Rack::MockRequest.env_for('http://host2/test', :method => 'PUT')).dest.should == :host2
      @router.recognize(Rack::MockRequest.env_for('http://host1/test', :method => 'POST')).dest.should == :post
      @router.recognize(Rack::MockRequest.env_for('http://host2/test', :method => 'GET')).dest.should == :host2_get
      @router.recognize(Rack::MockRequest.env_for('http://host2/test', :method => 'POST')).dest.should == :host2_post
    end

    it "should be able to use regexp in request method conditions" do
      @router.get("/test").host(/host1/).to(:with_regexp)
      @router.get("/test").to(:without_regexp)
      @router.recognize(Rack::MockRequest.env_for('http://host2/test')).dest.should == :without_regexp
      @router.recognize(Rack::MockRequest.env_for('http://host2.host1.com/test')).dest.should == :with_regexp
    end

    it "should try both specific and non-specifc routes" do
      @router.post("/test").host('host1').to(:post_host1)
      @router.add("/test").host('host2').to(:any_post2)
      @router.recognize(Rack::MockRequest.env_for('http://host2/test', :method => 'POST')).dest.should == :any_post2
    end

    it "should match on scheme" do
      @router.get("/test").scheme('http').to(:http)
      @router.get("/test").scheme('https').to(:https)
      @router.recognize(Rack::MockRequest.env_for('http://example.org/test')).dest.should == :http
      @router.recognize(Rack::MockRequest.env_for('https://example.org/test')).dest.should == :https
      @router.recognize(Rack::MockRequest.env_for('https://example.org/test', :method => 'POST')).matched?.should be_false
    end

  end

  context("with dynamic paths") do
    it "should recognize /foo/:id and /foo" do
      @router.add("/foo/:id").to(:test2)
      @router.add("/foo").to(:test1)
      @router.recognize(Rack::MockRequest.env_for('/foo')).dest.should == :test1
      @router.recognize(Rack::MockRequest.env_for('/foo/id')).dest.should == :test2
    end

    it "should recognize /foo/: and map it to $1" do
      @router.add("/foo/:").to(:test2)
      @router.recognize(Rack::MockRequest.env_for('/foo/id')).dest.should == :test2
      @router.recognize(Rack::MockRequest.env_for('/foo/id')).params_as_hash[:$1].should == 'id'
    end

    it "should use a static part as a variable if no further match is available" do
      @router.add("/foo/foo").to(:test1)
      @router.add("/:foo/foo2").to(:test2)
      @router.recognize(Rack::MockRequest.env_for('/foo/foo')).dest.should == :test1
      @router.recognize(Rack::MockRequest.env_for('/foo/foo2')).dest.should == :test2
    end

    it "should recognize /foo/:/: and map it to $1 and $2" do
      @router.add("/foo/:/:").to(:test2)
      @router.recognize(Rack::MockRequest.env_for('/foo/id/what')).dest.should == :test2
      @router.recognize(Rack::MockRequest.env_for('/foo/id/what')).params_as_hash[:$1].should == 'id'
      @router.recognize(Rack::MockRequest.env_for('/foo/id/what')).params_as_hash[:$2].should == 'what'
    end

    it "should recognize '/:variable'" do
      route = @router.add('/:variable').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/%E6%AE%BA%E3%81%99'))
      response.route.should == route
      response.params.should == ["\346\256\272\343\201\231"]
      response.params_as_hash[:variable].should == "\346\256\272\343\201\231"
    end

    it "should recognize '/:variable' and URI unescape variables" do
      route = @router.add('/:variable').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/value'))
      response.route.should == route
      response.params.should == ['value']
      response.params_as_hash[:variable].should == 'value'
    end

    it "should recognize using match_path" do
      route = @router.add('/:test').match_path(%r{/(test123|\d+)}).to(:test)
      @router.recognize(Rack::MockRequest.env_for('/test123')).params_as_hash[:test].should == 'test123'
      @router.recognize(Rack::MockRequest.env_for('/123')).params_as_hash[:test].should == '123'
      @router.recognize(Rack::MockRequest.env_for('/test321')).should be_nil
      @router.recognize(Rack::MockRequest.env_for('/test123andmore')).should be_nil
      @router.recognize(Rack::MockRequest.env_for('/lesstest123')).should be_nil
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

    it "should recognize '/(.:format)'" do
      route = @router.add('/(.:format)').to(:test)
      response = @router.recognize(Rack::MockRequest.env_for('/.html'))
      response.route.should == route
      response.params_as_hash[:format].should == 'html'
      response = @router.recognize(Rack::MockRequest.env_for('/'))
      response.route.should == route
      response.params_as_hash[:format].should be_nil
    end

    it "should recognize '/:test.:format'" do
      route = @router.add('/:test.:format').to(:test)
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

    context "with globs" do
      it "should recognize" do
        route = @router.add('/test/*variable').to(:test)
        response = @router.recognize(Rack::MockRequest.env_for('/test/one/two/three'))
        response.route.should == route
        response.params.should == [['one', 'two', 'three']]
      end

      it "should recognize" do
        route = @router.add('/test/*variable/test').to(:test)
        response = @router.recognize(Rack::MockRequest.env_for('/test/one/two/three/test'))
        response.route.should == route
        response.params.should == [['one', 'two', 'three']]
      end

      it "should recognize with a regexp" do
        route = @router.add('/test/*variable/anymore').matching(:variable => /\d+/).to(:test)
        response = @router.recognize(Rack::MockRequest.env_for('/test/123/345/567/anymore'))
        response.route.should == route
        response.params.should == [['123', '345', '567']]
        response = @router.recognize(Rack::MockRequest.env_for('/test/123/345/567'))
        response.should be_nil
      end

      it "should recognize /foo/*/test and map it to $1" do
        @router.add("/foo/*/test").to(:test2)
        @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/test')).dest.should == :test2
        @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/test')).params_as_hash[:$1].should == ['id1', 'id2']
      end

      it "should recognize /foo/*/what/: and map it to $1 and $2" do
        @router.add("/foo/*/what/:").to(:test2)
        @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/what/more')).dest.should == :test2
        @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/what/more')).params_as_hash[:$1].should == ['id1', 'id2']
        @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/what/more')).params_as_hash[:$2].should == 'more'
      end
    end

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
