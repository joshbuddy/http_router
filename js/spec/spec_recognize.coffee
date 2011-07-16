util = require 'util'
require '../lib/sherpa'
minitest = require('./minitest.js/minitest')
minitest.setupListeners()
assert = require('assert')

minitest.context "Sherpa#recognize()", ->
  @setup ->
    @router = new Sherpa()

  @assertion "should recognize a simple route", (test) ->
    @router.add('/').to (req, params) ->
      assert.deepEqual {}, params
      test.finished()
    @router.match url: '/'

  @assertion "should recognize another simple route ", (test) ->
    @router.add('/test').to (req, params) ->
      assert.deepEqual {}, params
      test.finished()
    @router.match url: '/test'
    
  @assertion "should recognize a route with a variable", (test) ->
    @router.add('/:test').to (req, params) ->
      assert.deepEqual test: 'variable', params
      test.finished()
    @router.match url: '/variable'


  @assertion "should recognize a route with an interstitial variable", (test) ->
    @router.add('/test-:test-test').to (req, params) ->
      assert.deepEqual {test: 'variable'}, params
      test.finished()
    @router.match url: '/test-variable-test'


  @assertion "should recognize a route with a variable at the end of the path", (test) ->
    @router.add('/test/:test').to (req, params) ->
      assert.deepEqual {test: 'variable'}, params
      test.finished()
    @router.match url: '/test/variable'

  @assertion "should recognize a simple route with optionals", (test) ->
    count = 0
    @router.add('/(test)').to (req, params) ->
      assert.deepEqual {}, params
      test.finished() if count == 1
      count++
    @router.match url: '/'
    @router.match url: '/test'

  @assertion "should recognize a route based on a request method", (test) ->
    routes = []
    @router.add('/test', conditions: {method: 'GET'}).to (req, params) ->
      assert.deepEqual {}, params
      routes.push 'get'
    @router.add('/test', conditions: {method: 'POST'}).to (req, params) ->
      assert.deepEqual {}, params
      routes.push 'post'
    @router.add('/test').to (req, params) ->
      assert.deepEqual {}, params
      assert.deepEqual ['get', 'post'], routes
      routes.push 'post'
      test.finished();
    @router.match url: '/test', method: 'GET'
    @router.match url: '/test', method: 'POST'
    @router.match url: '/test', method: 'PUT'

  @assertion "should recognize a simple route with nested optionals", (test) ->
    urls = []
    @router.callback = ->
      assert.deepEqual ['/test', '/test/test2', '/test/test2/test3'], urls
      test.finished()
    @router.add('/test(/test2(/test3))').to (req, params) ->
      assert.deepEqual {}, params
      urls.push req.url
    @router.match url:'/test'
    @router.match url:'/test/test2'
    @router.match url:'/test/test2/test3'
    @router.match url:'/test/test3'


  @assertion "should recognize a route based on multiple request keys", (test) ->
    routes = []
    @router.add('/test', conditions: {method: 'GET',  scheme: 'http' }).to -> routes.push('http-get')
    @router.add('/test', conditions: {method: 'POST', scheme: 'http' }).to -> routes.push('http-post')
    @router.add('/test', conditions: {method: 'POST', scheme: 'https'}).to -> routes.push('https-post')
    @router.add('/test', conditions: {method: 'GET',  scheme: 'https'}).to -> routes.push('https-get')
    @router.add('/test', conditions: {                scheme: 'http' }).to -> routes.push('http-any')
    @router.add('/test', conditions: {                scheme: 'https'}).to -> routes.push('https-any')
    @router.callback = ->
      assert.deepEqual ['http-post', 'http-get', 'http-any', 'https-get', 'https-post', 'https-any'], routes
      test.finished()
    
    @router.match url: '/test', method: 'POST', scheme: 'http'
    @router.match url: '/test', method: 'GET',  scheme: 'http'
    @router.match url: '/test', method: 'PUT',  scheme: 'http' 
    @router.match url: '/test', method: 'GET',  scheme: 'https'
    @router.match url: '/test', method: 'POST', scheme: 'https'
    @router.match url: '/test', method: 'PUT',  scheme: 'https'
    @router.match url: '/'


  @assertion "should recognize a partial route", (test) ->
    @router.add('/test', partial: true).to -> test.finished()
    @router.match(url:'/test/testing')

  @assertion "should recognize a route with a regex variable in it", (test) ->
    vars = ['123', 'qwe', 'asd']
    missedCount = 0
    @router.callback = -> missedCount++
    @router.add('/:test', matchesWith: {test: /asd|qwe|\d+/}).to (req, params) ->
      assert.equal 2, missedCount
      assert.deepEqual {test: vars.shift()}, params
      test.finished() if vars.length == 0

    @router.match(url:'/variable')
    @router.match(url:'/123qwe')
    @router.match(url:'/123')
    @router.match(url:'/qwe')
    @router.match(url:'/asd')

  @assertion "should distinguish between identical routes where one has a matchesWith", (test) ->
    params = []
    nonParams = []
    @router.add('/:test', matchesWith: {test: /^(asd|qwe|\d+)$/}).to (req, p)->
      params.push p
    @router.add('/:test').to (req, p) ->
      nonParams.push p
      if params.length == 3 and nonParams.length == 2
        assert.deepEqual [{test: '123'}, {test:'qwe'}, {test: 'asd'}], params
        assert.deepEqual [{test: 'poipio'}, {test:'123asd'}], nonParams
        test.finished()

    @router.match url:'/123'
    @router.match url:'/qwe'
    @router.match url:'/asd'
    @router.match url:'/poipio'
    @router.match url:'/123asd'

  @assertion "should recognize a route based on a request method", (test) ->
    routes = []
    @router.add('/test', conditions:{method: 'GET'}).to -> routes.push('get')
    @router.add('/test', conditions:{method: 'POST'}).to -> routes.push('post')
    @router.add('/test').to ->
      assert.deepEqual(['get', 'post'], routes)
      test.finished()
    @router.match(url:'/test', method: 'GET')
    @router.match(url:'/test', method: 'POST')
    @router.match(url:'/test', method: 'PUT')


  @assertion "should recognize a route based on a request method regex", (test) ->
    routes = []
    @router.add('/test', conditions:{method: 'DELETE'}).to -> routes.push('delete')
    @router.add('/test', conditions:{method: /GET|POST/}).to -> routes.push('get-post')
    @router.add('/test').to ->
      assert.deepEqual ['get-post', 'get-post', 'delete'], routes
      test.finished()
    @router.match(url:'/test', method: 'GET')
    @router.match(url:'/test', method: 'POST')
    @router.match(url:'/test', method: 'DELETE')
    @router.match(url:'/test', method: 'PUT')
