require('../sherpa');

exports.Sherpa = Sherpa;

var url = require('url');

Sherpa.NodeJs = function (routes) {
  this.routes = routes;
};

Sherpa.NodeJs.prototype = {
  listener: function() {
    var router = new Sherpa.Router();
    router.callback = function(req, res) {
      res.writeHead(404, {});
      res.end();
    }

    for(var key in this.routes) {
      if (this.routes[key][0] == 'not found') {
        router.callback = function() { this.routes[key][1](req, res) };
      } else {
        switch(this.routes[key].length) {
          case 2:
            router.add(this.routes[key][0]).to(function(req, params) {
              this.routes[key][1](req, res, params)
            });
            break;
          case 3:
            router.add(this.routes[key][0], this.routes[key][1]).to(function(req, params) {
              this.routes[key][2](req, res, params)
            });
            break;
          default:
            throw("must be 2 or 3");
        }
      }
    }

    router.callback = notFound

    return function(httpRequest, httpResponse) {
      var requestUrl = url.parse(httpRequest.url)
      var response = router.match(httpRequest);
      if (response) {
        httpRequest.sherpaResponse = response;
        response.destination(httpRequest, httpResponse);
      } else {
        notFound(httpRequest, httpResponse);
      }
    }

  }
}

