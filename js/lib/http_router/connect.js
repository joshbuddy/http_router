require('../sherpa');

module.exports = Sherpa;

var url = require('url');

Sherpa.Connect = function () {
  Sherpa.Router.call(this)
};

function getMatched(groups){
  var matched =[];
  for (i in groups){
    matched.push(groups[i].join("/"));
  }
  return "/" + matched.join("/");
}


Sherpa.Connect.prototype = new Sherpa.Router();
var proto = Sherpa.Connect.prototype;

var sys = require('sys');
function addMethodRoute(_method, path, opts, fn){
  if (!fn){
    fn = opts;
    opts = undefined;
  }

  opts = opts || {};
  opts.conditions = opts.conditions || {};
  opts.conditions.method = _method;
  return this.add(path, opts);
}

function addRouteMethod(_method){
  proto[_meth] = function(path, opts){
    return addMethodRoute.call(this, _method, path, opts);
  }
}

var _methods = ['GET', 'PUT', 'POST', 'DELETE', 'OPTIONS', 'HEAD'];
for(i in _methods){
  var _meth = _methods[i];
  addRouteMethod(_meth);
}

proto.ANY = function(path, opts, fn){
  if (!fn){
    fn = opts;
    opts = undefined;
  }

  opts = opts || {};
  return this.add(path);
}

// The connector provides the standard Connect interface
proto.connect = function() {
  var self = this
  return function(httpRequest, httpResponse, next) {
    var requestUrl = url.parse(httpRequest.url)
    var response = self.recognize(requestUrl.pathname, httpRequest);
    if (response) {

      if(response.route.partial){
        var matched = getMatched(response.path.groups);
        httpRequest.url = httpRequest.url.replace(matched, "");

        if(httpRequest.url == "")
          httpRequest.url = "/";

        httpRequest.scriptName = httpRequest.scriptName || '';
        httpRequest.scriptName = httpRequest.scriptName + matched
      }

      httpRequest.sherpaResponse = response;

      if(response.destination.handle){
        response.destination.handle(httpRequest, httpResponse, next);
      } else {
        response.destination(httpRequest, httpResponse, next);
      }
    } else {
      next();
    }
  }
}

