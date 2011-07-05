(function() {
  var assert, minitest, util;
  util = require('util');
  require('../lib/sherpa');
  minitest = require('./minitest.js/minitest');
  minitest.setupListeners();
  assert = require('assert');
  minitest.context("Sherpa#generate()", function() {
    this.setup(function() {
      return this.router = new Sherpa();
    });
    this.assertion("should generate a simple route", function(test) {
      this.router.add('/test', {
        name: 'simple'
      });
      assert.equal('/test', this.router.url('simple'));
      return test.finished();
    });
    this.assertion("should generate a route with a variable in it", function(test) {
      this.router.add('/:test', {
        name: 'with_variable'
      });
      assert.equal('/var', this.router.url('with_variable', {
        test: 'var'
      }));
      return test.finished();
    });
    this.assertion("should generate a route with a regex variable in it", function(test) {
      this.router.add('/:test', {
        matchesWith: {
          test: /asd|qwe|\d+/
        },
        name: 'with_variable'
      });
      assert.equal(void 0, this.router.url('with_variable', {
        test: 'variable'
      }));
      assert.equal(void 0, this.router.url('with_variable', {
        test: '123qwe'
      }));
      assert.equal('/123', this.router.url('with_variable', {
        test: '123'
      }));
      assert.equal('/qwe', this.router.url('with_variable', {
        test: 'qwe'
      }));
      assert.equal('/asd', this.router.url('with_variable', {
        test: 'asd'
      }));
      return test.finished();
    });
    this.assertion("should generate a route with a optionals in it", function(test) {
      this.router.add('/(:test)', {
        name: 'with_optional'
      });
      assert.equal('/', this.router.url('with_optional'));
      assert.equal('/hello', this.router.url('with_optional', {
        test: 'hello'
      }));
      return test.finished();
    });
    this.assertion("should generate a route with nested optionals in it", function(test) {
      this.router.add('/(:test(/:test2))', {
        name: 'with_optional'
      });
      assert.equal('/', this.router.url('with_optional'));
      assert.equal('/hello', this.router.url('with_optional', {
        test: 'hello'
      }));
      assert.equal('/hello/world', this.router.url('with_optional', {
        test: 'hello',
        test2: 'world'
      }));
      assert.equal('/?test2=hello', this.router.url('with_optional', {
        test2: 'hello'
      }));
      return test.finished();
    });
    this.assertion("should generate extra params as a query string after", function(test) {
      this.router.add('/:test', {
        matchesWith: {
          test: /asd|qwe|\d+/
        },
        name: 'with_variable'
      });
      assert.equal('/123?foo=bar', this.router.url('with_variable', {
        test: '123',
        foo: 'bar'
      }));
      return test.finished();
    });
    this.assertion("should escape values in the URI", function(test) {
      this.router.add('/:test', {
        name: 'with_variable'
      });
      assert.equal('/%5B%20%5D+=-', this.router.url('with_variable', {
        test: '[ ]+=-'
      }));
      return test.finished();
    });
    return this.assertion("should escape values in the query string", function(test) {
      this.router.add('/', {
        name: 'simple'
      });
      assert.equal('/?test+and+more=%5B+%5D%2B%3D-', this.router.url('simple', {
        "test and more": '[ ]+=-'
      }));
      return test.finished();
    });
  });
}).call(this);
