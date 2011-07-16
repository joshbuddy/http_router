util = require 'util'
require '../lib/sherpa'
minitest = require('./minitest.js/minitest')
minitest.setupListeners()
assert = require('assert')

minitest.context "Sherpa#generate()", ->
  @setup ->
    @router = new Sherpa()

  @assertion "should generate a simple route", (test) ->
    @router.add('/test', name: 'simple')
    assert.equal('/test', @router.url('simple'))
    test.finished()

  @assertion "should generate a route with a variable in it", (test) ->
    @router.add('/:test', name:'with_variable')
    assert.equal('/var', @router.url('with_variable', {test: 'var'}))
    test.finished()
  
  @assertion "should generate a route with a regex variable in it", (test) ->
    @router.add('/:test', matchesWith: {test: /asd|qwe|\d+/}, name: 'with_variable')
    assert.equal(undefined, @router.url('with_variable', {test: 'variable'}))
    assert.equal(undefined, @router.url('with_variable', {test: '123qwe'}))
    assert.equal('/123', @router.url('with_variable', {test: '123'}))
    assert.equal('/qwe', @router.url('with_variable', {test: 'qwe'}))
    assert.equal('/asd', @router.url('with_variable', {test: 'asd'}))
    test.finished()

  
  @assertion "should generate a route with a optionals in it", (test) ->
    @router.add('/(:test)', name:'with_optional')
    assert.equal('/', @router.url('with_optional'))
    assert.equal('/hello', @router.url('with_optional', test: 'hello'))
    test.finished()
  
  @assertion "should generate a route with nested optionals in it", (test) ->
    @router.add('/(:test(/:test2))', name: 'with_optional')
    assert.equal('/', @router.url('with_optional'))
    assert.equal('/hello', @router.url('with_optional', {test: 'hello'}))
    assert.equal('/hello/world', @router.url('with_optional', {test: 'hello', test2: 'world'}))
    assert.equal('/?test2=hello', @router.url('with_optional', {test2: 'hello'}))
    test.finished();

  @assertion "should generate extra params as a query string after", (test) ->
    @router.add('/:test', matchesWith: {test: /asd|qwe|\d+/},name:'with_variable')
    assert.equal('/123?foo=bar', @router.url('with_variable', {test: '123', foo: 'bar'}))
    test.finished();
  
  
  @assertion "should escape values in the URI", (test) ->
    @router.add('/:test', name: 'with_variable')
    assert.equal('/%5B%20%5D+=-', @router.url('with_variable', {test: '[ ]+=-'}))
    test.finished()
  
  @assertion "should escape values in the query string", (test) ->
    @router.add('/', name:'simple')
    assert.equal('/?test+and+more=%5B+%5D%2B%3D-', @router.url('simple', {"test and more": '[ ]+=-'}))
    test.finished()
