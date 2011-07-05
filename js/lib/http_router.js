(function() {
  var Sherpa, url, util;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  util = require('util');
  url = require('url');
  root.Sherpa = Sherpa = (function() {
    var Glob, Lookup, Node, Path, RegexMatcher, Request, RequestMatcher, Response, Route, SpanningRegexMatcher, Variable;
    function Sherpa(callback) {
      this.callback = callback;
      this.root = new Node();
      this.routes = {};
    }
    Sherpa.prototype.match = function(httpRequest, httpResponse) {
      var request;
      console.log("@httpResponse: " + (httpResponse != null));
      request = new Request(httpRequest);
      this.root.match(request);
      console.log("request.destinations.length: " + request.destinations.length);
      if (request.destinations.length > 0) {
        return new Response(request, httpResponse).invoke();
      } else if (this.callback != null) {
        return this.callback(request.underlyingRequest);
      }
    };
    Sherpa.prototype.findSubparts = function(part) {
      var match, subparts;
      subparts = [];
      while (match = part.match(/\\.|[:*][a-z0-9_]+|[^:*\\]+/)) {
        part = part.slice(match.index, part.length);
        subparts.push(part.slice(0, match[0].length));
        part = part.slice(match[0].length, part.length);
      }
      return subparts;
    };
    Sherpa.prototype.generatePaths = function(path) {
      var c, charIndex, chars, endIndex, pathIndex, paths, startIndex, _ref, _ref2;
      _ref = [[''], path.split(''), 0, 1], paths = _ref[0], chars = _ref[1], startIndex = _ref[2], endIndex = _ref[3];
      for (charIndex = 0, _ref2 = chars.length; 0 <= _ref2 ? charIndex < _ref2 : charIndex > _ref2; 0 <= _ref2 ? charIndex++ : charIndex--) {
        c = chars[charIndex];
        switch (c) {
          case '(':
            for (pathIndex = startIndex; startIndex <= endIndex ? pathIndex < endIndex : pathIndex > endIndex; startIndex <= endIndex ? pathIndex++ : pathIndex--) {
              paths.push(paths[pathIndex]);
            }
            startIndex = endIndex;
            endIndex = paths.length;
            break;
          case ')':
            startIndex -= endIndex - startIndex;
            break;
          default:
            for (pathIndex = startIndex; startIndex <= endIndex ? pathIndex < endIndex : pathIndex > endIndex; startIndex <= endIndex ? pathIndex++ : pathIndex--) {
              paths[pathIndex] += c;
            }
        }
      }
      return paths;
    };
    Sherpa.prototype.url = function(name, params) {
      var _ref;
      return (_ref = this.routes[name]) != null ? _ref.url(params) : void 0;
    };
    Sherpa.prototype.addComplexPart = function(subparts, compiledPath, matchesWith, variableNames) {
      var captures, capturingIndicies, name, part, regexSubparts, regexp, spans, splittingIndicies, _ref;
      _ref = [[], [], 0, false], capturingIndicies = _ref[0], splittingIndicies = _ref[1], captures = _ref[2], spans = _ref[3];
      regexSubparts = (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = subparts.length; _i < _len; _i++) {
          part = subparts[_i];
          _results.push((function() {
            var _ref2;
            switch (part[0]) {
              case '\\':
                return escape(part[1].chr);
              case ':':
              case '*':
                if (part[0] === '*') {
                  spans = true;
                }
                captures += 1;
                name = part.slice(1, part.length);
                variableNames.push(name);
                if (part[0] === '*') {
                  splittingIndicies.push(captures);
                  compiledPath.push("params['" + name + "'].join('/')");
                } else {
                  capturingIndicies.push(captures);
                  compiledPath.push("params['" + name + "']");
                }
                if (spans) {
                  if (matchesWith[name] != null) {
                    return "((?:" + matchesWith[name].source + "\\/?)+)";
                  } else {
                    return '(.*?)';
                  }
                } else {
                  return "(" + (((_ref2 = matchesWith[name]) != null ? _ref2.source : void 0) || '[^/]*?') + ")";
                }
                break;
              default:
                compiledPath.push("'" + part + "'");
                return escape(part);
            }
          })());
        }
        return _results;
      })();
      regexp = new RegExp("" + (regexSubparts.join('')) + "$");
      if (spans) {
        return new SpanningRegexMatcher(regexp, capturingIndicies, splittingIndicies);
      } else {
        return new RegexMatcher(regexp, capturingIndicies, splittingIndicies);
      }
    };
    Sherpa.prototype.addSimplePart = function(subparts, compiledPath, matchesWith, variableNames) {
      var part, variableName;
      part = subparts[0];
      switch (part[0]) {
        case ':':
          variableName = part.slice(1, part.length);
          compiledPath.push("params['" + variableName + "']");
          variableNames.push(variableName);
          if (matchesWith[variableName] != null) {
            return new SpanningRegexMatcher(matchesWith[variableName], [0], []);
          } else {
            return new Variable();
          }
          break;
        case '*':
          compiledPath.push("params['" + variableName + "'].join('/')");
          variableName = part.slice(1, part.length);
          variableNames.push(variableName);
          return new Glob();
        default:
          compiledPath.push("'" + part + "'");
          return new Lookup(part);
      }
    };
    Sherpa.prototype.add = function(rawPath, opts) {
      var compiledPath, defaults, escape, matchesWith, nextNodeFn, node, part, parts, path, pathSet, route, routeName, subparts, variableNames;
      matchesWith = (opts != null ? opts.matchesWith : void 0) || {};
      defaults = (opts != null ? opts["default"] : void 0) || {};
      routeName = opts != null ? opts.name : void 0;
      pathSet = (function() {
        var _i, _j, _len, _len2, _ref, _results;
        _ref = this.generatePaths(rawPath);
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          path = _ref[_i];
          node = this.root;
          variableNames = [];
          parts = path.split('/');
          compiledPath = [];
          escape = function(str) {
            return str.replace(/([.*+?^=!:${}()|[\]\/\\])/g, '\\$1');
          };
          for (_j = 0, _len2 = parts.length; _j < _len2; _j++) {
            part = parts[_j];
            if (part === '') {} else {
              compiledPath.push("'/'");
              subparts = this.findSubparts(part);
              nextNodeFn = subparts.length === 1 ? this.addSimplePart : this.addComplexPart;
              node = node.add(nextNodeFn(subparts, compiledPath, matchesWith, variableNames));
            }
          }
          if ((opts != null ? opts.conditions : void 0) != null) {
            node = node.add(new RequestMatcher(opts.conditions));
          }
          path = new Path(node, variableNames);
          path.partial = !!(opts != null ? opts.partial : void 0);
          path.compiled = compiledPath.length === 0 ? "'/'" : compiledPath.join('+');
          _results.push(path);
        }
        return _results;
      }).call(this);
      route = new Route(pathSet, matchesWith);
      route["default"] = defaults;
      route.name = routeName;
      if (routeName != null) {
        this.routes[routeName] = route;
      }
      return route;
    };
    Response = (function() {
      function Response(request, httpResponse, position) {
        this.request = request;
        this.httpResponse = httpResponse;
        this.position = position;
        this.position || (this.position = 0);
      }
      Response.prototype.next = function() {
        if (this.position === this.destinations.length - 1) {
          return false;
        } else {
          return new Response(this.request, this.httpResponse, this.position + 1).invoke();
        }
      };
      Response.prototype.invoke = function() {
        console.log("@httpResponse: " + (this.httpResponse != null) + " " + (util.inspect(this.request.destinations[this.position].route.name)) + " " + this.position + " " + this.request.destinations[this.position].route.destination + " named: " + this.request.destinations[this.position].route.name + " " + this.position);
        this.request.underlyingRequest.params = this.request.destinations[this.position].params;
        this.request.underlyingRequest.route = this.request.destinations[this.position].route;
        return this.request.destinations[this.position].route.destination(this.request.underlyingRequest, this.httpResponse);
      };
      return Response;
    })();
    Node = (function() {
      function Node() {
        this.type || (this.type = 'node');
        this.matchers = [];
      }
      Node.prototype.add = function(n) {
        var _ref;
        if (!((_ref = this.matchers[this.matchers.length - 1]) != null ? _ref.usable(n) : void 0)) {
          this.matchers.push(n);
        }
        return this.matchers[this.matchers.length - 1].use(n);
      };
      Node.prototype.usable = function(n) {
        return n.type === this.type;
      };
      Node.prototype.match = function(request) {
        var m, _i, _len, _ref, _results;
        _ref = this.matchers;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          m = _ref[_i];
          _results.push(m.match(request));
        }
        return _results;
      };
      Node.prototype.superMatch = Node.prototype.match;
      Node.prototype.use = function(n) {
        return this;
      };
      return Node;
    })();
    Lookup = (function() {
      __extends(Lookup, Node);
      function Lookup(part) {
        this.part = part;
        this.type = 'lookup';
        this.map = {};
        Lookup.__super__.constructor.apply(this, arguments);
      }
      Lookup.prototype.match = function(request) {
        var part;
        console.log("matching lookup " + (util.inspect(request.path[0])) + " " + (this.map[request.path[0]] != null));
        if (this.map[request.path[0]] != null) {
          request = request.clone();
          part = request.path.shift();
          return this.map[part].match(request);
        }
      };
      Lookup.prototype.use = function(n) {
        var _base, _name;
        (_base = this.map)[_name = n.part] || (_base[_name] = new Node());
        return this.map[n.part];
      };
      return Lookup;
    })();
    Variable = (function() {
      __extends(Variable, Node);
      function Variable() {
        this.type || (this.type = 'variable');
        Variable.__super__.constructor.apply(this, arguments);
      }
      Variable.prototype.match = function(request) {
        console.log("matching variable " + (util.inspect(request.path[0])));
        if (request.path.length > 0) {
          request = request.clone();
          request.variables.push(request.path.shift());
          return Variable.__super__.match.call(this, request);
        }
      };
      return Variable;
    })();
    Glob = (function() {
      __extends(Glob, Variable);
      function Glob() {
        this.type = 'glob';
        Glob.__super__.constructor.apply(this, arguments);
      }
      Glob.prototype.match = function(request) {
        var globbed_variable, original_request, _results;
        if (request.path.length > 0) {
          original_request = request;
          globbed_variable = [];
          _results = [];
          while (request.path.length > 0) {
            request = request.clone();
            globbed_variable.push(request.path.shift());
            request.variables.push(globbed_variable);
            _results.push(this.superMatch(request));
          }
          return _results;
        }
      };
      return Glob;
    })();
    RegexMatcher = (function() {
      __extends(RegexMatcher, Node);
      function RegexMatcher(regexp, capturingIndicies, splittingIndicies) {
        this.regexp = regexp;
        this.capturingIndicies = capturingIndicies;
        this.splittingIndicies = splittingIndicies;
        this.type || (this.type = 'regex');
        RegexMatcher.__super__.constructor.apply(this, arguments);
      }
      RegexMatcher.prototype.match = function(request) {
        var i, match, _i, _j, _len, _len2, _ref, _ref2;
        if ((request.path[0] != null) && (match = request.path[0].match(this.regexp))) {
          request = request.clone();
          request.path.shift();
          _ref = this.splittingIndicies;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            i = _ref[_i];
            request.variables.push(match[i].split('/'));
          }
          _ref2 = this.capturingIndicies;
          for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
            i = _ref2[_j];
            request.variables.push(match[i]);
          }
          return RegexMatcher.__super__.match.call(this, request);
        }
      };
      RegexMatcher.prototype.usable = function(n) {
        return n.type === this.type && n.regexp === this.regexp && n.capturingIndicies === this.capturingIndicies && n.splittingIndicies === this.splittingIndicies;
      };
      return RegexMatcher;
    })();
    SpanningRegexMatcher = (function() {
      __extends(SpanningRegexMatcher, RegexMatcher);
      function SpanningRegexMatcher(regexp, capturingIndicies, splittingIndicies) {
        this.regexp = regexp;
        this.capturingIndicies = capturingIndicies;
        this.splittingIndicies = splittingIndicies;
        this.type = 'spanning';
        SpanningRegexMatcher.__super__.constructor.apply(this, arguments);
      }
      SpanningRegexMatcher.prototype.match = function(request) {
        var i, match, wholePath, _i, _j, _len, _len2, _ref, _ref2;
        if (request.path.length > 0) {
          wholePath = request.path.join('/');
          if (match = wholePath.match(this.regexp)) {
            request = request.clone();
            _ref = this.splittingIndicies;
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              i = _ref[_i];
              request.variables.push(match[i].split('/'));
            }
            _ref2 = this.capturingIndicies;
            for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
              i = _ref2[_j];
              request.variables.push(match[i]);
            }
            request.splitPath(wholePath.slice(match.index + match[0].length, wholePath.length));
            return this.superMatch(request);
          }
        }
      };
      return SpanningRegexMatcher;
    })();
    RequestMatcher = (function() {
      __extends(RequestMatcher, Node);
      function RequestMatcher(conditions) {
        this.conditions = conditions;
        this.type = 'request';
        RequestMatcher.__super__.constructor.apply(this, arguments);
      }
      RequestMatcher.prototype.match = function(request) {
        var conditionCount, matcher, matching, satisfiedConditionCount, type, v, val, _ref;
        conditionCount = 0;
        satisfiedConditionCount = 0;
        _ref = this.conditions;
        for (type in _ref) {
          matcher = _ref[type];
          val = request.underlyingRequest[type];
          conditionCount++;
          v = matcher instanceof Array ? (matching = function() {
            var cond, _i, _len;
            for (_i = 0, _len = matcher.length; _i < _len; _i++) {
              cond = matcher[_i];
              if (cond.exec != null) {
                if (matcher.exec(val)) {
                  return true;
                }
              } else {
                if (cond === val) {
                  return true;
                }
              }
            }
            return false;
          }, matching()) : matcher.exec != null ? matcher.exec(val) : matcher === val;
          if (v) {
            satisfiedConditionCount++;
          }
        }
        if (conditionCount === satisfiedConditionCount) {
          return RequestMatcher.__super__.match.call(this, request);
        }
      };
      RequestMatcher.prototype.usable = function(n) {
        return n.type === this.type && n.conditions === this.conditions;
      };
      return RequestMatcher;
    })();
    Path = (function() {
      __extends(Path, Node);
      function Path(parent, variableNames) {
        this.parent = parent;
        this.variableNames = variableNames;
        this.type = 'path';
        this.partial = false;
      }
      Path.prototype.match = function(request) {
        console.log("matched! " + this.route.name);
        if (this.partial || request.path.length === 0) {
          return request.destinations.push({
            route: this.route,
            request: request,
            params: this.constructParams(request)
          });
        }
      };
      Path.prototype.constructParams = function(request) {
        var i, params, _ref;
        params = {};
        for (i = 0, _ref = this.variableNames.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
          params[this.variableNames[i]] = request.variables[i];
        }
        return params;
      };
      Path.prototype.url = function(rawParams) {
        var key, match, name, params, path, _i, _j, _k, _len, _len2, _len3, _ref, _ref2, _ref3;
        if (rawParams == null) {
          rawParams = {};
        }
        params = {};
        _ref = this.variableNames;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          key = _ref[_i];
          params[key] = this.route["default"] != null ? rawParams[key] || this.route["default"][key] : rawParams[key];
          if (!(params[key] != null)) {
            return;
          }
        }
        _ref2 = this.variableNames;
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          name = _ref2[_j];
          if (this.route.matchesWith[name] != null) {
            match = params[name].match(this.route.matchesWith[name]);
            if (!((match != null) && match[0].length === params[name].length)) {
              return;
            }
          }
        }
        path = this.compiled === '' ? '' : eval(this.compiled);
        if (path != null) {
          _ref3 = this.variableNames;
          for (_k = 0, _len3 = _ref3.length; _k < _len3; _k++) {
            name = _ref3[_k];
            delete rawParams[name];
          }
          return path;
        }
      };
      return Path;
    })();
    Route = (function() {
      function Route(pathSet, matchesWith) {
        var path, _i, _len, _ref;
        this.pathSet = pathSet;
        this.matchesWith = matchesWith;
        _ref = this.pathSet;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          path = _ref[_i];
          path.route = this;
        }
      }
      Route.prototype.to = function(destination) {
        var path, _i, _len, _ref, _results;
        this.destination = destination;
        _ref = this.pathSet;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          path = _ref[_i];
          _results.push(path.parent.add(path));
        }
        return _results;
      };
      Route.prototype.generateQuery = function(params, base, query) {
        var idx, k, v, _ref;
        query = "";
        base || (base = "");
        if (params != null) {
          if (params instanceof Array) {
            for (idx = 0, _ref = params.length; 0 <= _ref ? idx < _ref : idx > _ref; 0 <= _ref ? idx++ : idx--) {
              query += this.generateQuery(params[idx], "" + base + "[]");
            }
          } else if (params instanceof Object) {
            for (k in params) {
              v = params[k];
              query += this.generateQuery(v, base === '' ? k : "" + base + "[" + k + "]");
            }
          } else {
            query += encodeURIComponent(base).replace(/%20/g, '+');
            query += '=';
            query += encodeURIComponent(params).replace(/%20/g, '+');
            query += '&';
          }
        }
        return query;
      };
      Route.prototype.url = function(params) {
        var joiner, path, pathIdx, query, _ref;
        path = void 0;
        for (pathIdx = _ref = this.pathSet.length - 1; _ref <= 0 ? pathIdx <= 0 : pathIdx >= 0; _ref <= 0 ? pathIdx++ : pathIdx--) {
          path = this.pathSet[pathIdx].url(params);
          if (path != null) {
            break;
          }
        }
        if (path != null) {
          query = this.generateQuery(params);
          joiner = query !== '' ? '?' : '';
          return "" + (encodeURI(path)) + joiner + (query.substr(0, query.length - 1));
        } else {
          return;
        }
      };
      return Route;
    })();
    Request = (function() {
      function Request(underlyingRequest, callback) {
        this.underlyingRequest = underlyingRequest;
        this.callback = callback;
        this.variables = [];
        this.destinations = [];
        if (this.underlyingRequest != null) {
          this.path = this.splitPath(this.underlyingRequest.url);
        }
      }
      Request.prototype.toString = function() {
        return "<Request path: /" + (this.path.join('/')) + " " + this.path.length + ">";
      };
      Request.prototype.splitPath = function(path) {
        var splitPath;
        splitPath = /^\/?$/.exec(path) ? [] : decodeURI(url.parse(path).pathname).split('/');
        if (splitPath[0] === '') {
          splitPath.shift();
        }
        console.log("splitPath: " + (util.inspect(splitPath)));
        return splitPath;
      };
      Request.prototype.clone = function() {
        var c;
        c = new Request();
        c.path = this.path.slice(0, this.path.length);
        c.variables = this.variables.slice(0, this.variables.length);
        c.underlyingRequest = this.underlyingRequest;
        c.callback = this.callback;
        c.destinations = this.destinations;
        return c;
      };
      return Request;
    })();
    return Sherpa;
  })();
}).call(this);
