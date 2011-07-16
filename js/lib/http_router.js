(function() {
  var Sherpa;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor;
    child.__super__ = parent.prototype;
    return child;
  };
  root.Sherpa = Sherpa = (function() {
    var Glob, Lookup, Node, Path, PathRequest, RegexMatcher, RegexPath, Request, RequestMatcher, Response, Route, SpanningRegexMatcher, Variable;
    function Sherpa(callback) {
      this.callback = callback;
      this.root = new Node();
      this.routes = {};
    }
    Sherpa.prototype.match = function(httpRequest, httpResponse) {
      var request;
      request = (httpRequest.url != null) ? new Request(httpRequest) : new PathRequest(httpRequest);
      this.root.match(request);
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
      var add, c, charIndex, chars, endIndex, pathIndex, paths, startIndex, _ref, _ref2;
      _ref = [[''], path.split(''), 0, 1], paths = _ref[0], chars = _ref[1], startIndex = _ref[2], endIndex = _ref[3];
      for (charIndex = 0, _ref2 = chars.length; 0 <= _ref2 ? charIndex < _ref2 : charIndex > _ref2; 0 <= _ref2 ? charIndex++ : charIndex--) {
        c = chars[charIndex];
        switch (c) {
          case '\\':
            charIndex++;
            add = chars[charIndex] === ')' || chars[charIndex] === '(' ? chars[charIndex] : "\\" + chars[charIndex];
            for (pathIndex = startIndex; startIndex <= endIndex ? pathIndex < endIndex : pathIndex > endIndex; startIndex <= endIndex ? pathIndex++ : pathIndex--) {
              paths[pathIndex] += add;
            }
            break;
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
      paths.reverse();
      return paths;
    };
    Sherpa.prototype.url = function(name, params) {
      var _ref;
      return (_ref = this.routes[name]) != null ? _ref.url(params) : void 0;
    };
    Sherpa.prototype.addComplexPart = function(subparts, compiledPath, matchesWith, variableNames) {
      var captures, capturingIndicies, escapeRegexp, name, part, regexSubparts, regexp, spans, splittingIndicies, _ref;
      escapeRegexp = function(str) {
        return str.replace(/([\.*+?^=!:${}()|[\]\/\\])/g, '\\$1');
      };
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
                compiledPath.push("'" + part[1] + "'");
                return escapeRegexp(part[1]);
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
                return escapeRegexp(part);
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
          return new Glob(matchesWith[variableName]);
        default:
          compiledPath.push("'" + part + "'");
          return new Lookup(part);
      }
    };
    Sherpa.prototype.add = function(rawPath, opts) {
      var compiledPath, defaults, matchesWith, nextNodeFn, node, part, partiallyMatch, parts, path, pathSet, route, routeName, subparts, variableNames;
      matchesWith = (opts != null ? opts.matchesWith : void 0) || {};
      defaults = (opts != null ? opts["default"] : void 0) || {};
      routeName = opts != null ? opts.name : void 0;
      partiallyMatch = false;
      route = rawPath.exec != null ? new Route([this.root.add(new RegexPath(this.root, rawPath))]) : (rawPath.substring(rawPath.length - 1) === '*' ? (rawPath = rawPath.substring(0, rawPath.length - 1), partiallyMatch = true) : void 0, pathSet = (function() {
        var _i, _j, _len, _len2, _ref, _results;
        _ref = this.generatePaths(rawPath);
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          path = _ref[_i];
          node = this.root;
          variableNames = [];
          parts = path.split('/');
          compiledPath = [];
          for (_j = 0, _len2 = parts.length; _j < _len2; _j++) {
            part = parts[_j];
            if (part !== '') {
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
          path.partial = partiallyMatch;
          path.compiled = compiledPath.length === 0 ? "'/'" : compiledPath.join('+');
          _results.push(path);
        }
        return _results;
      }).call(this), new Route(pathSet, matchesWith));
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
        var req;
        req = typeof this.request.underlyingRequest === 'string' ? {} : this.request.underlyingRequest;
        req.params = this.request.destinations[this.position].params;
        req.route = this.request.destinations[this.position].route;
        req.pathInfo = this.request.destinations[this.position].pathInfo;
        return this.request.destinations[this.position].route.destination(req, this.httpResponse);
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
      function Glob(regexp) {
        this.regexp = regexp;
        this.type = 'glob';
        Glob.__super__.constructor.apply(this, arguments);
      }
      Glob.prototype.match = function(request) {
        var cloned_path, i, match, original_request, _ref, _results;
        if (request.path.length > 0) {
          original_request = request;
          cloned_path = request.path.slice(0, request.path);
          _results = [];
          for (i = 1, _ref = original_request.path.length; 1 <= _ref ? i <= _ref : i >= _ref; 1 <= _ref ? i++ : i--) {
            request = original_request.clone();
            if (this.regexp != null) {
              match = request.path[i - 1].match(this.regexp);
            }
            if ((this.regexp != null) && (!(match != null) || match[0].length !== request.path[i - 1].length)) {
              return;
            }
            request.variables.push(request.path.slice(0, i));
            request.path = request.path.slice(i, request.path.length);
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
        var i, _i, _j, _len, _len2, _ref, _ref2;
        this.regexp = regexp;
        this.capturingIndicies = capturingIndicies;
        this.splittingIndicies = splittingIndicies;
        this.type || (this.type = 'regex');
        this.varIndicies = [];
        _ref = this.splittingIndicies;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          i = _ref[_i];
          this.varIndicies[i] = [i, 'split'];
        }
        _ref2 = this.capturingIndicies;
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          i = _ref2[_j];
          this.varIndicies[i] = [i, 'capture'];
        }
        this.varIndicies.sort(function(a, b) {
          return a[0] - b[0];
        });
        RegexMatcher.__super__.constructor.apply(this, arguments);
      }
      RegexMatcher.prototype.match = function(request) {
        var match;
        if ((request.path[0] != null) && (match = request.path[0].match(this.regexp))) {
          if (match[0].length !== request.path[0].length) {
            return;
          }
          request = request.clone();
          this.addVariables(request, match);
          request.path.shift();
          return RegexMatcher.__super__.match.call(this, request);
        }
      };
      RegexMatcher.prototype.addVariables = function(request, match) {
        var idx, type, v, _i, _len, _ref, _results;
        _ref = this.varIndicies;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          v = _ref[_i];
          if (v != null) {
            idx = v[0];
            type = v[1];
            _results.push((function() {
              switch (type) {
                case 'split':
                  return request.variables.push(match[idx].split('/'));
                case 'capture':
                  return request.variables.push(match[idx]);
              }
            })());
          }
        }
        return _results;
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
        var match, wholePath;
        if (request.path.length > 0) {
          wholePath = request.wholePath();
          if (match = wholePath.match(this.regexp)) {
            if (match.index !== 0) {
              return;
            }
            request = request.clone();
            this.addVariables(request, match);
            request.path = request.splitPath(wholePath.slice(match.index + match[0].length, wholePath.length));
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
      Path.prototype.addDestination = function(request) {
        return request.destinations.push({
          route: this.route,
          request: request,
          params: this.constructParams(request)
        });
      };
      Path.prototype.match = function(request) {
        if (this.partial || request.path.length === 0) {
          this.addDestination(request);
          if (this.partial) {
            return request.destinations[request.destinations.length - 1].pathInfo = "/" + (request.wholePath());
          }
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
    RegexPath = (function() {
      __extends(RegexPath, Path);
      function RegexPath(parent, regexp) {
        this.parent = parent;
        this.regexp = regexp;
        this.type = 'regexp_route';
        RegexPath.__super__.constructor.apply(this, arguments);
      }
      RegexPath.prototype.match = function(request) {
        request.regexpRouteMatch = this.regexp.exec(request.decodedPath());
        if ((request.regexpRouteMatch != null) && request.regexpRouteMatch[0].length === request.decodedPath().length) {
          request = request.clone();
          request.path = [];
          return RegexPath.__super__.match.call(this, request);
        }
      };
      RegexPath.prototype.constructParams = function(request) {
        return request.regexpRouteMatch;
      };
      RegexPath.prototype.url = function(rawParams) {
        throw "This route cannot be generated";
      };
      return RegexPath;
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
        var joiner, path, pathObj, query, _i, _len, _ref;
        path = void 0;
        _ref = this.pathSet;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          pathObj = _ref[_i];
          path = pathObj.url(params);
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
          this.path = this.splitPath();
        }
      }
      Request.prototype.toString = function() {
        return "<Request path: /" + (this.path.join('/')) + " " + this.path.length + ">";
      };
      Request.prototype.wholePath = function() {
        return this.path.join('/');
      };
      Request.prototype.decodedPath = function(path) {
        if (path == null) {
          path = require('url').parse(this.underlyingRequest.url).pathname;
        }
        return decodeURI(path);
      };
      Request.prototype.splitPath = function(path) {
        var decodedPath, splitPath;
        decodedPath = this.decodedPath(path);
        splitPath = decodedPath === '/' ? [] : decodedPath.split('/');
        if (splitPath[0] === '') {
          splitPath.shift();
        }
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
    PathRequest = (function() {
      __extends(PathRequest, Request);
      function PathRequest() {
        PathRequest.__super__.constructor.apply(this, arguments);
      }
      PathRequest.prototype.decodedPath = function(path) {
        if (path == null) {
          path = this.underlyingRequest;
        }
        return decodeURI(path);
      };
      return PathRequest;
    })();
    return Sherpa;
  })();
}).call(this);
