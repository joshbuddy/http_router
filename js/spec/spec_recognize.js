(function() {
  var assert, minitest, util;
  util = require('util');
  require('../lib/sherpa');
  minitest = require('./minitest.js/minitest');
  minitest.setupListeners();
  assert = require('assert');
  minitest.context("Sherpa#recognize()", function() {
    this.setup(function() {
      return this.router = new Sherpa();
    });
    this.assertion("should recognize a simple route", function(test) {
      this.router.add('/').to(function(req, params) {
        assert.deepEqual({}, params);
        return test.finished();
      });
      return this.router.match({
        url: '/'
      });
    });
    this.assertion("should recognize another simple route ", function(test) {
      this.router.add('/test').to(function(req, params) {
        assert.deepEqual({}, params);
        return test.finished();
      });
      return this.router.match({
        url: '/test'
      });
    });
    this.assertion("should recognize a route with a variable", function(test) {
      this.router.add('/:test').to(function(req, params) {
        assert.deepEqual({
          test: 'variable'
        }, params);
        return test.finished();
      });
      return this.router.match({
        url: '/variable'
      });
    });
    this.assertion("should recognize a route with an interstitial variable", function(test) {
      this.router.add('/test-:test-test').to(function(req, params) {
        assert.deepEqual({
          test: 'variable'
        }, params);
        return test.finished();
      });
      return this.router.match({
        url: '/test-variable-test'
      });
    });
    this.assertion("should recognize a route with a variable at the end of the path", function(test) {
      this.router.add('/test/:test').to(function(req, params) {
        assert.deepEqual({
          test: 'variable'
        }, params);
        return test.finished();
      });
      return this.router.match({
        url: '/test/variable'
      });
    });
    this.assertion("should recognize a simple route with optionals", function(test) {
      var count;
      count = 0;
      this.router.add('/(test)').to(function(req, params) {
        assert.deepEqual({}, params);
        if (count === 1) {
          test.finished();
        }
        return count++;
      });
      this.router.match({
        url: '/'
      });
      return this.router.match({
        url: '/test'
      });
    });
    this.assertion("should recognize a route based on a request method", function(test) {
      var routes;
      routes = [];
      this.router.add('/test', {
        conditions: {
          method: 'GET'
        }
      }).to(function(req, params) {
        assert.deepEqual({}, params);
        return routes.push('get');
      });
      this.router.add('/test', {
        conditions: {
          method: 'POST'
        }
      }).to(function(req, params) {
        assert.deepEqual({}, params);
        return routes.push('post');
      });
      this.router.add('/test').to(function(req, params) {
        assert.deepEqual({}, params);
        assert.deepEqual(['get', 'post'], routes);
        routes.push('post');
        return test.finished();
      });
      this.router.match({
        url: '/test',
        method: 'GET'
      });
      this.router.match({
        url: '/test',
        method: 'POST'
      });
      return this.router.match({
        url: '/test',
        method: 'PUT'
      });
    });
    this.assertion("should recognize a simple route with nested optionals", function(test) {
      var urls;
      urls = [];
      this.router.callback = function() {
        assert.deepEqual(['/test', '/test/test2', '/test/test2/test3'], urls);
        return test.finished();
      };
      this.router.add('/test(/test2(/test3))').to(function(req, params) {
        assert.deepEqual({}, params);
        return urls.push(req.url);
      });
      this.router.match({
        url: '/test'
      });
      this.router.match({
        url: '/test/test2'
      });
      this.router.match({
        url: '/test/test2/test3'
      });
      return this.router.match({
        url: '/test/test3'
      });
    });
    this.assertion("should recognize a route based on multiple request keys", function(test) {
      var routes;
      routes = [];
      this.router.add('/test', {
        conditions: {
          method: 'GET',
          scheme: 'http'
        }
      }).to(function() {
        return routes.push('http-get');
      });
      this.router.add('/test', {
        conditions: {
          method: 'POST',
          scheme: 'http'
        }
      }).to(function() {
        return routes.push('http-post');
      });
      this.router.add('/test', {
        conditions: {
          method: 'POST',
          scheme: 'https'
        }
      }).to(function() {
        return routes.push('https-post');
      });
      this.router.add('/test', {
        conditions: {
          method: 'GET',
          scheme: 'https'
        }
      }).to(function() {
        return routes.push('https-get');
      });
      this.router.add('/test', {
        conditions: {
          scheme: 'http'
        }
      }).to(function() {
        return routes.push('http-any');
      });
      this.router.add('/test', {
        conditions: {
          scheme: 'https'
        }
      }).to(function() {
        return routes.push('https-any');
      });
      this.router.callback = function() {
        assert.deepEqual(['http-post', 'http-get', 'http-any', 'https-get', 'https-post', 'https-any'], routes);
        return test.finished();
      };
      this.router.match({
        url: '/test',
        method: 'POST',
        scheme: 'http'
      });
      this.router.match({
        url: '/test',
        method: 'GET',
        scheme: 'http'
      });
      this.router.match({
        url: '/test',
        method: 'PUT',
        scheme: 'http'
      });
      this.router.match({
        url: '/test',
        method: 'GET',
        scheme: 'https'
      });
      this.router.match({
        url: '/test',
        method: 'POST',
        scheme: 'https'
      });
      this.router.match({
        url: '/test',
        method: 'PUT',
        scheme: 'https'
      });
      return this.router.match({
        url: '/'
      });
    });
    this.assertion("should recognize a partial route", function(test) {
      this.router.add('/test', {
        partial: true
      }).to(function() {
        return test.finished();
      });
      return this.router.match({
        url: '/test/testing'
      });
    });
    this.assertion("should recognize a route with a regex variable in it", function(test) {
      var missedCount, vars;
      vars = ['123', 'qwe', 'asd'];
      missedCount = 0;
      this.router.callback = function() {
        return missedCount++;
      };
      this.router.add('/:test', {
        matchesWith: {
          test: /asd|qwe|\d+/
        }
      }).to(function(req, params) {
        assert.equal(2, missedCount);
        assert.deepEqual({
          test: vars.shift()
        }, params);
        if (vars.length === 0) {
          return test.finished();
        }
      });
      this.router.match({
        url: '/variable'
      });
      this.router.match({
        url: '/123qwe'
      });
      this.router.match({
        url: '/123'
      });
      this.router.match({
        url: '/qwe'
      });
      return this.router.match({
        url: '/asd'
      });
    });
    this.assertion("should distinguish between identical routes where one has a matchesWith", function(test) {
      var nonParams, params;
      params = [];
      nonParams = [];
      this.router.add('/:test', {
        matchesWith: {
          test: /^(asd|qwe|\d+)$/
        }
      }).to(function(req, p) {
        return params.push(p);
      });
      this.router.add('/:test').to(function(req, p) {
        nonParams.push(p);
        if (params.length === 3 && nonParams.length === 2) {
          assert.deepEqual([
            {
              test: '123'
            }, {
              test: 'qwe'
            }, {
              test: 'asd'
            }
          ], params);
          assert.deepEqual([
            {
              test: 'poipio'
            }, {
              test: '123asd'
            }
          ], nonParams);
          return test.finished();
        }
      });
      this.router.match({
        url: '/123'
      });
      this.router.match({
        url: '/qwe'
      });
      this.router.match({
        url: '/asd'
      });
      this.router.match({
        url: '/poipio'
      });
      return this.router.match({
        url: '/123asd'
      });
    });
    this.assertion("should recognize a route based on a request method", function(test) {
      var routes;
      routes = [];
      this.router.add('/test', {
        conditions: {
          method: 'GET'
        }
      }).to(function() {
        return routes.push('get');
      });
      this.router.add('/test', {
        conditions: {
          method: 'POST'
        }
      }).to(function() {
        return routes.push('post');
      });
      this.router.add('/test').to(function() {
        assert.deepEqual(['get', 'post'], routes);
        return test.finished();
      });
      this.router.match({
        url: '/test',
        method: 'GET'
      });
      this.router.match({
        url: '/test',
        method: 'POST'
      });
      return this.router.match({
        url: '/test',
        method: 'PUT'
      });
    });
    return this.assertion("should recognize a route based on a request method regex", function(test) {
      var routes;
      routes = [];
      this.router.add('/test', {
        conditions: {
          method: 'DELETE'
        }
      }).to(function() {
        return routes.push('delete');
      });
      this.router.add('/test', {
        conditions: {
          method: /GET|POST/
        }
      }).to(function() {
        return routes.push('get-post');
      });
      this.router.add('/test').to(function() {
        assert.deepEqual(['get-post', 'get-post', 'delete'], routes);
        return test.finished();
      });
      this.router.match({
        url: '/test',
        method: 'GET'
      });
      this.router.match({
        url: '/test',
        method: 'POST'
      });
      this.router.match({
        url: '/test',
        method: 'DELETE'
      });
      return this.router.match({
        url: '/test',
        method: 'PUT'
      });
    });
  });
}).call(this);
