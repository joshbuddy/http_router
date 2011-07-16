root.Sherpa = class Sherpa
  constructor: (@callback) ->
    @root = new Node()
    @routes = {}
  match: (httpRequest, httpResponse) ->
    request = if (httpRequest.url?) then new Request(httpRequest) else new PathRequest(httpRequest)
    @root.match(request)
    if request.destinations.length > 0
      new Response(request, httpResponse).invoke()
    else if @callback?
      @callback(request.underlyingRequest)
  findSubparts: (part) ->
    subparts = []
    while match = part.match(/\\.|[:*][a-z0-9_]+|[^:*\\]+/)
      part = part.slice(match.index, part.length)
      subparts.push part.slice(0, match[0].length)
      part = part.slice(match[0].length, part.length)
    subparts
  generatePaths: (path) ->
    [paths, chars, startIndex, endIndex] = [[''], path.split(''), 0, 1]
    for charIndex in [0...chars.length]
      c = chars[charIndex]
      switch c
        when '\\'
          # do nothing ... 
          charIndex++
          add = if chars[charIndex] == ')' or chars[charIndex] == '('
            chars[charIndex]
          else
            "\\#{chars[charIndex]}"
          paths[pathIndex] += add for pathIndex in [startIndex...endIndex]
        when '('
          # over current working set, double paths
          paths.push(paths[pathIndex]) for pathIndex in [startIndex...endIndex]
          # move working set to newly copied paths
          startIndex = endIndex
          endIndex = paths.length
        when ')'
          startIndex -= endIndex - startIndex
        else
          paths[pathIndex] += c for pathIndex in [startIndex...endIndex]
    paths.reverse()
    paths
  url: (name, params) ->
    @routes[name]?.url(params)
  addComplexPart: (subparts, compiledPath, matchesWith, variableNames) ->
    escapeRegexp = (str) -> str.replace(/([\.*+?^=!:${}()|[\]\/\\])/g, '\\$1')
    [capturingIndicies, splittingIndicies, captures, spans] = [[], [], 0, false]
    regexSubparts = for part in subparts
      switch part[0]
        when '\\'
          compiledPath.push "'#{part[1]}'"
          escapeRegexp(part[1])
        when ':', '*'
          spans = true if part[0] == '*'
          captures += 1
          name = part.slice(1, part.length)
          variableNames.push(name)
          if part[0] == '*'
            splittingIndicies.push(captures)
            compiledPath.push "params['#{name}'].join('/')"
          else
            capturingIndicies.push(captures)
            compiledPath.push "params['#{name}']"
          if spans
            if matchesWith[name]? then "((?:#{matchesWith[name].source}\\/?)+)" else '(.*?)'
          else
            "(#{(matchesWith[name]?.source || '[^/]*?')})"
        else
          compiledPath.push "'#{part}'"
          escapeRegexp(part)
    regexp = new RegExp("#{regexSubparts.join('')}$")
    if spans
      new SpanningRegexMatcher(regexp, capturingIndicies, splittingIndicies)
    else
      new RegexMatcher(regexp, capturingIndicies, splittingIndicies)
  addSimplePart: (subparts, compiledPath, matchesWith, variableNames) ->
    part = subparts[0]
    switch part[0]
      when ':'
        variableName = part.slice(1, part.length)
        compiledPath.push "params['#{variableName}']"
        variableNames.push(variableName)
        if matchesWith[variableName]? then new SpanningRegexMatcher(matchesWith[variableName], [0], []) else new Variable() 
      when '*'
        compiledPath.push "params['#{variableName}'].join('/')"
        variableName = part.slice(1, part.length)
        variableNames.push(variableName)
        new Glob(matchesWith[variableName])
      else
        compiledPath.push "'#{part}'"
        new Lookup(part)
  add: (rawPath, opts) ->
    matchesWith = opts?.matchesWith || {}
    defaults = opts?.default || {}
    routeName = opts?.name
    partiallyMatch = false
    route = if rawPath.exec?
      new Route([@root.add(new RegexPath(@root, rawPath))])
    else
      if rawPath.substring(rawPath.length - 1) == '*'
        rawPath = rawPath.substring(0, rawPath.length - 1)
        partiallyMatch = true
      pathSet = for path in @generatePaths(rawPath)
        node = @root
        variableNames = []
        parts = path.split('/')
        compiledPath = []
        for part in parts
          unless part == ''
            compiledPath.push "'/'"
            subparts = @findSubparts(part)
            nextNodeFn = if subparts.length == 1 then @addSimplePart else @addComplexPart
            node = node.add(nextNodeFn(subparts, compiledPath, matchesWith, variableNames))
        if opts?.conditions?
          node = node.add(new RequestMatcher(opts.conditions))
        path = new Path(node, variableNames)
        path.partial = partiallyMatch
        path.compiled = if compiledPath.length == 0 then "'/'" else compiledPath.join('+')
        path
      new Route(pathSet, matchesWith)
    route.default = defaults
    route.name = routeName
    @routes[routeName] = route if routeName?
    route

  class Response
    constructor: (@request, @httpResponse, @position) ->
      @position ||= 0
    next: ->
      if @position == @destinations.length - 1
        false
      else
        new Response(@request, @httpResponse, @position + 1).invoke()
    invoke: ->
      req = if typeof(@request.underlyingRequest) == 'string' then {} else @request.underlyingRequest
      req.params = @request.destinations[@position].params
      req.route = @request.destinations[@position].route
      req.pathInfo = @request.destinations[@position].pathInfo
      @request.destinations[@position].route.destination(req, @httpResponse)

  class Node
    constructor: ->
      @type ||= 'node'
      @matchers = []
    add: (n) ->
      @matchers.push(n) if !@matchers[@matchers.length - 1]?.usable(n)
      @matchers[@matchers.length - 1].use(n)
    usable: (n) -> n.type == @type
    match: (request) ->
      m.match(request) for m in @matchers
    superMatch: Node::match
    use: (n) -> this

  class Lookup extends Node
    constructor: (part) ->
      @part = part  
      @type = 'lookup'
      @map = {}
      super
    match: (request) ->
      if @map[request.path[0]]?
        request = request.clone()
        part = request.path.shift()
        @map[part].match(request)
    use: (n) ->
      @map[n.part] ||= new Node()
      @map[n.part]
  
  class Variable extends Node
    constructor: ->
      @type ||= 'variable'
      super
    match: (request) ->
      if request.path.length > 0
        request = request.clone()
        request.variables.push(request.path.shift())
        super(request)
      
  class Glob extends Variable
    constructor: (@regexp) ->
      @type = 'glob'
      super
    match: (request) ->
      if request.path.length > 0
        original_request = request
        cloned_path = request.path.slice(0, request.path)
        for i in [1..original_request.path.length]
          request = original_request.clone()
          match = request.path[i - 1].match(@regexp) if @regexp?
          return if @regexp? and (!match? or match[0].length != request.path[i - 1].length)
          request.variables.push(request.path.slice(0, i))
          request.path = request.path.slice(i, request.path.length)
          @superMatch(request)

  class RegexMatcher extends Node
    constructor: (@regexp, @capturingIndicies, @splittingIndicies) ->
      @type ||= 'regex'
      @varIndicies = []
      @varIndicies[i] = [i, 'split'] for i in @splittingIndicies
      @varIndicies[i] = [i, 'capture'] for i in @capturingIndicies
      @varIndicies.sort (a, b) -> a[0] - b[0]
      super
    match: (request) ->
      if request.path[0]? and match = request.path[0].match(@regexp)
        return unless match[0].length == request.path[0].length
        request = request.clone()
        @addVariables(request, match)
        request.path.shift()
        super(request)
    addVariables: (request, match) ->
      for v in @varIndicies when v?
        idx = v[0]
        type = v[1]
        switch type
          when 'split' then request.variables.push match[idx].split('/')
          when 'capture' then request.variables.push match[idx]
    usable: (n) ->
      n.type == @type && n.regexp == @regexp && n.capturingIndicies == @capturingIndicies && n.splittingIndicies == @splittingIndicies
    
  class SpanningRegexMatcher extends RegexMatcher
    constructor: (@regexp, @capturingIndicies, @splittingIndicies) ->
      @type = 'spanning'
      super
    match: (request) ->
      if request.path.length > 0
        wholePath = request.wholePath()
        if match = wholePath.match(@regexp)
          return unless match.index == 0
          request = request.clone()
          @addVariables(request, match)
          request.path = request.splitPath(wholePath.slice(match.index + match[0].length, wholePath.length))
          @superMatch(request)
      
  class RequestMatcher extends Node
    constructor: (@conditions) ->
      @type = 'request'
      super
    match: (request) ->
      conditionCount = 0
      satisfiedConditionCount = 0
      for type, matcher of @conditions
        val = request.underlyingRequest[type]
        conditionCount++
        v = if matcher instanceof Array
          matching = ->
            for cond in matcher
              if cond.exec?
                return true if matcher.exec(val)
              else
                return true if cond == val
            false
          matching()
        else
          if matcher.exec? then matcher.exec(val) else matcher == val
        satisfiedConditionCount++ if v
      if conditionCount == satisfiedConditionCount
        super(request)
    usable: (n) ->
      n.type == @type && n.conditions == @conditions

  class Path extends Node
    constructor: (@parent, @variableNames) ->
      @type = 'path'
      @partial = false
    addDestination: (request) -> request.destinations.push({route: @route, request: request, params: @constructParams(request)})
    match: (request) ->
      if @partial or request.path.length == 0
        @addDestination(request)
        if @partial
          request.destinations[request.destinations.length - 1].pathInfo = "/#{request.wholePath()}"
    constructParams: (request) ->
      params = {}
      for i in [0...@variableNames.length]
        params[@variableNames[i]] = request.variables[i]
      params
    url: (rawParams) ->
      rawParams = {} unless rawParams?
      params = {}
      for key in @variableNames
        params[key] = if @route.default? then rawParams[key] || @route.default[key] else rawParams[key]
        return undefined if !params[key]?
      for name in @variableNames
        if @route.matchesWith[name]?
          match = params[name].match(@route.matchesWith[name])
          return undefined unless match? && match[0].length == params[name].length
      path = if @compiled == '' then '' else eval(@compiled)
      if path?
        delete rawParams[name] for name in @variableNames
        path

  class RegexPath extends Path
    constructor: (@parent, @regexp) ->
      @type = 'regexp_route'
      super
    match: (request) ->
      request.regexpRouteMatch = @regexp.exec(request.decodedPath())
      if request.regexpRouteMatch? && request.regexpRouteMatch[0].length == request.decodedPath().length
        request = request.clone()
        request.path = []
        super(request)
    constructParams: (request) -> request.regexpRouteMatch
    url: (rawParams) -> throw("This route cannot be generated")

  class Route
    constructor: (@pathSet, @matchesWith) ->
      path.route = this for path in @pathSet
    to: (@destination) ->
      path.parent.add(path) for path in @pathSet
    generateQuery: (params, base, query) ->
      query = ""
      base ||= ""
      if params?
        if params instanceof Array
          for idx in [0...(params.length)]
            query += @generateQuery(params[idx], "#{base}[]")
        else if params instanceof Object
          for k,v of params
            query += @generateQuery(v, if base == '' then k else "#{base}[#{k}]")
        else
          query += encodeURIComponent(base).replace(/%20/g, '+')
          query += '='
          query += encodeURIComponent(params).replace(/%20/g, '+')
          query += '&'
      query
    url: (params) ->
      path = undefined
      for pathObj in @pathSet
        path = pathObj.url(params)
        break if path?
      if path?
        query = @generateQuery(params)
        joiner = if query != '' then '?' else ''
        "#{encodeURI(path)}#{joiner}#{query.substr(0, query.length - 1)}"
      else
        undefined

  class Request
    constructor: (@underlyingRequest, @callback) ->
      @variables = []
      @destinations = []
      if @underlyingRequest?
        @path = @splitPath()
    toString: -> "<Request path: /#{@path.join('/') } #{@path.length}>"
    wholePath: -> @path.join('/')
    decodedPath: (path) ->
      unless path?
        path = require('url').parse(@underlyingRequest.url).pathname
      decodeURI(path)
    splitPath: (path) ->
      decodedPath = @decodedPath(path)
      splitPath = if decodedPath == '/' then [] else decodedPath.split('/')
      splitPath.shift() if splitPath[0] == ''
      splitPath
    clone: ->
      c = new Request()
      c.path = @path.slice(0, @path.length)
      c.variables = @variables.slice(0, @variables.length)
      c.underlyingRequest = @underlyingRequest
      c.callback = @callback
      c.destinations = @destinations
      c

  class PathRequest extends Request
    decodedPath: (path) ->
      unless path?
        path = @underlyingRequest
      decodeURI(path)
