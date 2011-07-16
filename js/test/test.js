(function() {
  var Example, GenerationTest, RecognitionTest, Test, assert, fs, http_router, sys, util;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  require.paths.push("" + __dirname + "/../lib");
  fs = require('fs');
  util = require('util');
  sys = require('sys');
  http_router = require('http_router');
  assert = require('assert');
  Example = (function() {
    function Example(routes, tests) {
      this.routes = routes;
      this.tests = tests;
    }
    return Example;
  })();
  Test = (function() {
    function Test(file) {
      var contents, currentTest, line, lines, parsedRoutes, r, routes, tests, _i, _j, _len, _len2;
      this.examples = [];
      contents = fs.readFileSync(file, 'utf8');
      lines = contents.split(/\n/m);
      currentTest = null;
      routes = [];
      tests = [];
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        line = lines[_i];
        if (line.match(/^#/)) {} else if (line.match(/^\s*$/)) {} else if (line.match(/^(  |\t)/)) {
          tests.push(JSON.parse(line));
        } else {
          if (tests.length !== 0) {
            this.examples.push(new Example(routes, tests));
            routes = [];
            tests = [];
          }
          parsedRoutes = JSON.parse(line);
          if (parsedRoutes instanceof Array) {
            for (_j = 0, _len2 = parsedRoutes.length; _j < _len2; _j++) {
              r = parsedRoutes[_j];
              routes.push(r);
            }
          } else {
            routes.push(parsedRoutes);
          }
        }
      }
      this.examples.push(new Example(routes, tests));
    }
    Test.prototype.interpretValue = function(v) {
      if (v.regex != null) {
        return new RegExp(v.regex);
      } else {
        return v;
      }
    };
    Test.prototype.invoke = function() {
      throw "need to implement";
    };
    Test.prototype.constructRouter = function(example) {
      var conditions, k, matchesWith, name, opts, path, route, router, v, vals, _i, _len, _ref, _ref2;
      router = new Sherpa();
      _ref = example.routes;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        route = _ref[_i];
        for (name in route) {
          vals = route[name];
          path = null;
          opts = {
            name: name
          };
          if (vals.path != null) {
            path = this.interpretValue(vals.path);
            delete vals.path;
            if (vals.conditions != null) {
              conditions = {};
              _ref2 = vals.conditions;
              for (k in _ref2) {
                v = _ref2[k];
                switch (k) {
                  case 'request_method':
                    conditions.method = this.interpretValue(v);
                    break;
                  default:
                    conditions[k] = this.interpretValue(v);
                }
              }
              opts.conditions = conditions;
              delete vals.conditions;
            }
            if (vals["default"] != null) {
              opts["default"] = vals["default"];
              delete vals["default"];
            }
            matchesWith = {};
            for (k in vals) {
              v = vals[k];
              matchesWith[k] = this.interpretValue(v);
              delete vals.k;
            }
            opts.matchesWith = matchesWith;
          } else {
            path = this.interpretValue(vals);
          }
          name = "" + name;
          router.add(path, opts).to(function(req, response) {
            response.params = req.params;
            return response.end(req.route.name);
          });
        }
      }
      return router;
    };
    return Test;
  })();
  GenerationTest = (function() {
    __extends(GenerationTest, Test);
    function GenerationTest() {
      GenerationTest.__super__.constructor.apply(this, arguments);
    }
    GenerationTest.prototype.invoke = function() {
      var actualResult, example, expectedResult, name, params, router, test, _i, _j, _len, _len2, _ref, _ref2;
      console.log("Running " + this.examples.length + " generation tests");
      _ref = this.examples;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        example = _ref[_i];
        process.stdout.write("*");
        router = this.constructRouter(example);
        _ref2 = example.tests;
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          test = _ref2[_j];
          process.stdout.write(".");
          expectedResult = test[0], name = test[1], params = test[2];
          if ((params != null) && params instanceof Array) {
            continue;
          }
          if (name instanceof Object) {
            continue;
          }
          actualResult = router.url(name, params);
          assert.equal(expectedResult, actualResult);
        }
      }
      return console.log("\nDone!");
    };
    return GenerationTest;
  })();
  RecognitionTest = (function() {
    __extends(RecognitionTest, Test);
    function RecognitionTest() {
      RecognitionTest.__super__.constructor.apply(this, arguments);
    }
    RecognitionTest.prototype.invoke = function() {
      var complex, example, expectedParams, expectedRouteName, k, mockRequest, mockResponse, pathInfoExcpectation, requestingPath, router, test, v, _i, _j, _len, _len2, _ref, _ref2;
      console.log("Running " + this.examples.length + " recognition tests");
      _ref = this.examples;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        example = _ref[_i];
        process.stdout.write("*");
        router = this.constructRouter(example);
        _ref2 = example.tests;
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          test = _ref2[_j];
          mockResponse = {
            end: function(part) {
              return this.val = part;
            }
          };
          process.stdout.write(".");
          expectedRouteName = test[0], requestingPath = test[1], expectedParams = test[2];
          mockRequest = {};
          complex = false;
          if (requestingPath.path != null) {
            complex = true;
            mockRequest.url = requestingPath.path;
            delete requestingPath.path;
            for (k in requestingPath) {
              v = requestingPath[k];
              mockRequest[k] = v;
            }
          } else {
            mockRequest.url = requestingPath;
          }
          if (!mockRequest.url.match(/^http/)) {
            mockRequest.url = "http://host" + mockRequest.url;
          }
          router.match(mockRequest, mockResponse);
          assert.equal(expectedRouteName, mockResponse.val);
          expectedParams || (expectedParams = {});
          mockResponse.params || (mockResponse.params = {});
          pathInfoExcpectation = null;
          if (expectedParams.PATH_INFO != null) {
            pathInfoExcpectation = expectedParams.PATH_INFO;
            delete expectedParams.PATH_INFO;
          }
          if (pathInfoExcpectation) {
            assert.equal(pathInfoExcpectation, mockRequest.pathInfo);
          }
          assert.deepEqual(expectedParams, mockResponse.params);
          if (!complex) {
            mockResponse = {
              end: function(part) {
                return this.val = part;
              }
            };
            router.match(requestingPath, mockResponse);
            assert.equal(expectedRouteName, mockResponse.val);
            expectedParams || (expectedParams = {});
            mockResponse.params || (mockResponse.params = {});
            if (pathInfoExcpectation) {
              assert.equal(pathInfoExcpectation, mockRequest.pathInfo);
            }
            assert.deepEqual(expectedParams, mockResponse.params);
          }
        }
      }
      return console.log("\nDone!");
    };
    return RecognitionTest;
  })();
  new GenerationTest("" + __dirname + "/../../test/common/generate.txt").invoke();
  new RecognitionTest("" + __dirname + "/../../test/common/recognize.txt").invoke();
}).call(this);
