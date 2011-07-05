require.paths.push('lib')
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

  invoke: -> throw("need to implement")
  constructRouter: (example) ->
    router = new Sherpa()
    console.log("example.routes: #{example.routes.length}")
    for route in example.routes
      for name, vals of route
        path = null
        opts = {name: name}
        if vals.path?
          path = vals.path
          delete vals.path
          opts[k] = v for k, v of vals
        else
          path = vals
        name = "" + name
        router.add(path, opts).to (req, response) ->
          console.log("response: #{util.inspect(response)} #{req.route.name} #{req.url}")
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
        url = requestingPath
        url = "http://host#{url}" unless url.match(/^http/)
        mockRequest = url: url
        router.match(mockRequest, mockResponse)
        assert.equal(expectedRouteName, mockResponse.val)
        expectedParams ||= {}
        mockResponse.params ||= {}
        assert.deepEqual(expectedParams, mockResponse.params)
    console.log("\nDone!")

#new GenerationTest("#{__dirname}/../test/common/generate.txt").invoke()
new RecognitionTest("#{__dirname}/../test/common/recognize.txt").invoke()

