class TestVariable < MiniTest::Unit::TestCase
  def test_variable
    assert_route router.add(':one'),      '/two',        {:one => 'two'}
    assert_route router.add('test/:one'), '/test/three', {:one => 'three'}
  end

  def test_variable_vs_static
    dynamic, static = router { add ':one'; add 'one' }
    assert_route dynamic, '/two', {:one => 'two'}
    assert_route static,  '/one'
  end

  def test_variable_vs_glob
    glob, variable = router { 
      add '*var'
      add ':var'
    }
    assert_route variable,     '/two',     {:var => 'two'}
    assert_route glob,         '/two/two', {:var => %w{two two}}
  end

  def test_variable_with_static_after
    variable, static = router { 
      add '/:var/one'
      add 'one'
    }
    assert_route variable,     '/two/one', {:var => 'two'}
    assert_route static,       '/one'
    assert_route nil,          '/two'
  end
  
  #context("with dynamic paths") do
  #  it "should recognize /foo/:id and /foo" do
  #    @router.add("/foo/:id").to(:test2)
  #    @router.add("/foo").to(:test1)
  #    @router.recognize(Rack::MockRequest.env_for('/foo')).dest.should == :test1
  #    @router.recognize(Rack::MockRequest.env_for('/foo/id')).dest.should == :test2
  #  end
  #
  #  it "should recognize /foo/: and map it to $1" do
  #    @router.add("/foo/:").to(:test2)
  #    @router.recognize(Rack::MockRequest.env_for('/foo/id')).dest.should == :test2
  #    @router.recognize(Rack::MockRequest.env_for('/foo/id')).params_as_hash[:$1].should == 'id'
  #  end
  #
  #  it "should use a static part as a variable if no further match is available" do
  #    @router.add("/foo/foo").to(:test1)
  #    @router.add("/:foo/foo2").to(:test2)
  #    @router.recognize(Rack::MockRequest.env_for('/foo/foo')).dest.should == :test1
  #    @router.recognize(Rack::MockRequest.env_for('/foo/foo2')).dest.should == :test2
  #  end
  #
  #  it "should recognize /foo/:/: and map it to $1 and $2" do
  #    @router.add("/foo/:/:").to(:test2)
  #    @router.recognize(Rack::MockRequest.env_for('/foo/id/what')).dest.should == :test2
  #    @router.recognize(Rack::MockRequest.env_for('/foo/id/what')).params_as_hash[:$1].should == 'id'
  #    @router.recognize(Rack::MockRequest.env_for('/foo/id/what')).params_as_hash[:$2].should == 'what'
  #  end
  #
  #  it "should recognize '/:variable'" do
  #    route = @router.add('/:variable').to(:test)
  #    response = @router.recognize(Rack::MockRequest.env_for('/%E6%AE%BA%E3%81%99'))
  #    response.route.should == route
  #    response.params.should == ["\346\256\272\343\201\231"]
  #    response.params_as_hash[:variable].should == "\346\256\272\343\201\231"
  #  end
  #
  #  it "should recognize '/:variable' and URI unescape variables" do
  #    route = @router.add('/:variable').to(:test)
  #    response = @router.recognize(Rack::MockRequest.env_for('/value'))
  #    response.route.should == route
  #    response.params.should == ['value']
  #    response.params_as_hash[:variable].should == 'value'
  #  end
  #
  #  it "should recognize using match_path" do
  #    route = @router.add('/:test').match_path(%r{/(test123|\d+)}).to(:test)
  #    @router.recognize(Rack::MockRequest.env_for('/test123')).params_as_hash[:test].should == 'test123'
  #    @router.recognize(Rack::MockRequest.env_for('/123')).params_as_hash[:test].should == '123'
  #    @router.recognize(Rack::MockRequest.env_for('/test321')).should be_nil
  #    @router.recognize(Rack::MockRequest.env_for('/test123andmore')).should be_nil
  #    @router.recognize(Rack::MockRequest.env_for('/lesstest123')).should be_nil
  #  end
  #
  #  it "should recognize '/test.:format'" do
  #    route = @router.add('/test.:format').to(:test)
  #    response = @router.recognize(Rack::MockRequest.env_for('/test.html'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should == 'html'
  #    @router.recognize(Rack::MockRequest.env_for('/test')).should be_nil
  #  end
  #
  #  it "should recognize '/test(.:format)'" do
  #    route = @router.add('/test(.:format)').to(:test)
  #    response = @router.recognize(Rack::MockRequest.env_for('/test.html'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should == 'html'
  #    response = @router.recognize(Rack::MockRequest.env_for('/test'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should be_nil
  #  end
  #
  #  it "should recognize '/(.:format)'" do
  #    route = @router.add('/(.:format)').to(:test)
  #    response = @router.recognize(Rack::MockRequest.env_for('/.html'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should == 'html'
  #    response = @router.recognize(Rack::MockRequest.env_for('/'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should be_nil
  #  end
  #
  #  it "should recognize '/:test.:format'" do
  #    route = @router.add('/:test.:format').to(:test)
  #    response = @router.recognize(Rack::MockRequest.env_for('/hey.html'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should == 'html'
  #    response.params_as_hash[:test].should == 'hey'
  #  end
  #
  #  it "should recognize '/:test(.:format)'" do
  #    route = @router.add('/:test(.:format)').to(:test)
  #    response = @router.recognize(Rack::MockRequest.env_for('/hey.html'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should == 'html'
  #    response.params_as_hash[:test].should == 'hey'
  #    response = @router.recognize(Rack::MockRequest.env_for('/hey'))
  #    response.route.should == route
  #    response.params_as_hash[:format].should be_nil
  #    response.params_as_hash[:test].should == 'hey'
  #  end
  #
  #  context "with globs" do
  #    it "should recognize" do
  #      route = @router.add('/test/*variable').to(:test)
  #      response = @router.recognize(Rack::MockRequest.env_for('/test/one/two/three'))
  #      response.route.should == route
  #      response.params.should == [['one', 'two', 'three']]
  #    end
  #
  #    it "should recognize" do
  #      route = @router.add('/test/*variable/test').to(:test)
  #      response = @router.recognize(Rack::MockRequest.env_for('/test/one/two/three/test'))
  #      response.route.should == route
  #      response.params.should == [['one', 'two', 'three']]
  #    end
  #
  #    it "should recognize with a regexp" do
  #      route = @router.add('/test/*variable/anymore').matching(:variable => /\d+/).to(:test)
  #      response = @router.recognize(Rack::MockRequest.env_for('/test/123/345/567/anymore'))
  #      response.route.should == route
  #      response.params.should == [['123', '345', '567']]
  #      response = @router.recognize(Rack::MockRequest.env_for('/test/123/345/567'))
  #      response.should be_nil
  #    end
  #
  #    it "should recognize /foo/*/test and map it to $1" do
  #      @router.add("/foo/*/test").to(:test2)
  #      @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/test')).dest.should == :test2
  #      @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/test')).params_as_hash[:$1].should == ['id1', 'id2']
  #    end
  #
  #    it "should recognize /foo/*/what/: and map it to $1 and $2" do
  #      @router.add("/foo/*/what/:").to(:test2)
  #      @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/what/more')).dest.should == :test2
  #      @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/what/more')).params_as_hash[:$1].should == ['id1', 'id2']
  #      @router.recognize(Rack::MockRequest.env_for('/foo/id1/id2/what/more')).params_as_hash[:$2].should == 'more'
  #    end
  #  end
  #
  #end
  
end
