require.paths.push("#{__dirname}/../lib")
fs = require('fs')
util = require('util')
sys = require('sys')
http_router = require('http_router')
assert = require('assert')

class Example
  constructor: (@routes, @tests) ->

class Test
  constructor: (file)->
    @examples = []
    contents = fs.readFileSync(file, 'utf8')
    lines = contents.split(/\n/m)
    currentTest = null
    routes = []
    tests = []
    for line in lines
      if line.match(/^#/)
        # this is a comment, skip
      else if line.match(/^\s*$/)
        # empty line, skip
      else if line.match(/^(  |\t)/)
        # this is a test
        tests.push(JSON.parse(line))
      else
        # this is a route
        if tests.length != 0
          @examples.push new Example(routes, tests)
          routes = []
          tests = []
        parsedRoutes = JSON.parse(line)
        if parsedRoutes instanceof Array
          for r in parsedRoutes
            routes.push(r)
        else
          routes.push(parsedRoutes)
    @examples.push new Example(routes, tests)
  interpretValue: (v) ->
    if v.regex? then new RegExp(v.regex) else v
  invoke: -> throw("need to implement")
  constructRouter: (example) ->
    router = new Sherpa()
    for route in example.routes
      for name, vals of route
        path = null
        opts = {name: name}
        if vals.path?
          path = @interpretValue(vals.path)
          delete vals.path
          if vals.conditions?
            conditions = {}
            for k, v of vals.conditions
              switch k
                when 'request_method' then conditions.method = @interpretValue(v)
                else                       conditions[k]     = @interpretValue(v)
            opts.conditions = conditions
            delete vals.conditions
          if vals.default?
            opts.default = vals.default
            delete vals.default
          matchesWith = {}
          for k, v of vals
            matchesWith[k] = @interpretValue(v)
            delete vals.k
          opts.matchesWith = matchesWith
        else
          path = @interpretValue(vals)
        name = "" + name
        router.add(path, opts).to (req, response) ->
          response.params = req.params
          response.end(req.route.name)
    router

class GenerationTest extends Test
  constructor: -> super
  invoke: ->
    console.log("Running #{@examples.length} generation tests")
    for example in @examples
      process.stdout.write "*"
      router = @constructRouter(example)
      for test in example.tests
        process.stdout.write "."
        [expectedResult, name, params] = test
        continue if params? && params instanceof Array
        continue if name instanceof Object
        actualResult = router.url(name, params)
        assert.equal(expectedResult, actualResult)
    console.log("\nDone!")

class RecognitionTest extends Test
  constructor: -> super
  invoke: ->
    console.log("Running #{@examples.length} recognition tests")
    for example in @examples
      process.stdout.write "*"
      router = @constructRouter(example)
      for test in example.tests
        mockResponse = end: (part) -> @val = part
        process.stdout.write "."
        [expectedRouteName, requestingPath, expectedParams] = test
        mockRequest = {}
        complex = false
        if requestingPath.path?
          complex = true
          mockRequest.url = requestingPath.path
          delete requestingPath.path
          for k, v of requestingPath
            mockRequest[k] = v
        else
          mockRequest.url = requestingPath
        mockRequest.url = "http://host#{mockRequest.url}" unless mockRequest.url.match(/^http/)
        router.match(mockRequest, mockResponse)
        assert.equal(expectedRouteName, mockResponse.val)
        expectedParams ||= {}
        mockResponse.params ||= {}
        pathInfoExcpectation = null
        if expectedParams.PATH_INFO?
          pathInfoExcpectation = expectedParams.PATH_INFO
          delete expectedParams.PATH_INFO
        assert.equal(pathInfoExcpectation, mockRequest.pathInfo) if pathInfoExcpectation
        assert.deepEqual(expectedParams, mockResponse.params)
        unless complex
          mockResponse = end: (part) -> @val = part
          router.match(requestingPath, mockResponse)
          assert.equal(expectedRouteName, mockResponse.val)
          expectedParams ||= {}
          mockResponse.params ||= {}
          assert.equal(pathInfoExcpectation, mockRequest.pathInfo) if pathInfoExcpectation
          assert.deepEqual(expectedParams, mockResponse.params)
    console.log("\nDone!")

new GenerationTest("#{__dirname}/../../test/common/generate.txt").invoke()
new RecognitionTest("#{__dirname}/../../test/common/recognize.txt").invoke()

