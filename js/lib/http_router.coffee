util = require 'util'
url = require 'url'

root.Sherpa = class Sherpa
  constructor: (@callback) ->
    @root = new Node()
    @routes = {}
  match: (httpRequest, httpResponse) ->
    console.log("@httpResponse: #{httpResponse?}")
    request = new Request(httpRequest)
    @root.match(request)
    console.log("request.destinations.length: #{request.destinations.length}")
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
    escapeRegexp = (str) ->
      console.log("escaping #{util.inspect str}")
      replacement = str.replace(/([\.*+?^=!:${}()|[\]\/\\])/g, '\\$1')
      console.log("...with #{util.inspect replacement}")
      replacement
    [capturingIndicies, splittingIndicies, captures, spans] = [[], [], 0, false]
    regexSubparts = for part in subparts
      console.log(":part[0] -----> #{util.inspect part[0]}")
      switch part[0]
        when '\\'
          console.log("part[1]: #{util.inspect part[1]}")
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
          console.log("part: #{util.inspect part}")
          compiledPath.push "'#{part}'"
          escapeRegexp(part)
    regexp = new RegExp("#{regexSubparts.join('')}$")
    console.log "regexp: #{util.inspect regexp} spans: #{spans}"
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
    console.log("rawPath: #{util.inspect rawPath}")
    route = if rawPath.exec?
      new Route([@root.add(new RegexPath(@root, rawPath))])
    else
      console.log("@generatePaths(rawPath): #{util.inspect @generatePaths(rawPath)}")
      pathSet = for path in @generatePaths(rawPath)
        node = @root
        variableNames = []
        parts = path.split('/')
        compiledPath = []
        for part in parts
          if part == ''
            console.log("ignoring .. #{util.inspect parts}")
          else
            compiledPath.push "'/'"
            subparts = @findSubparts(part)
            console.log("subparts: #{util.inspect subparts}")
            nextNodeFn = if subparts.length == 1 then @addSimplePart else @addComplexPart
            node = node.add(nextNodeFn(subparts, compiledPath, matchesWith, variableNames))
        if opts?.conditions?
          node = node.add(new RequestMatcher(opts.conditions))
        console.log("creating Path for #{node.type}")
        path = new Path(node, variableNames)
        path.partial = !!opts?.partial
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
      console.log("@httpResponse: #{@httpResponse?} #{util.inspect @request.destinations[@position].route.name} #{@position} #{@request.destinations[@position].route.destination} named: #{@request.destinations[@position].route.name} #{@position}")
      @request.underlyingRequest.params = @request.destinations[@position].params
      @request.underlyingRequest.route = @request.destinations[@position].route
      @request.destinations[@position].route.destination(@request.underlyingRequest, @httpResponse)

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
      console.log("matching lookup #{util.inspect request.path[0]} #{@map[request.path[0]]?}")
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
      console.log("matching variable #{util.inspect request.path[0]}")
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
          console.log "request.variables[-1]: #{util.inspect request.variables[request.variables.length - 1]}"
          @superMatch(request)

  class RegexMatcher extends Node
    constructor: (@regexp, @capturingIndicies, @splittingIndicies) ->
      @type ||= 'regex'
      @varIndicies = []
      @varIndicies[i] = [i, 'split'] for i in @splittingIndicies
      @varIndicies[i] = [i, 'capture'] for i in @capturingIndicies
      @varIndicies.sort (a, b) -> a[0] - b[0]
      console.log("varIndicies: #{util.inspect @varIndicies} #{util.inspect @splittingIndicies} #{util.inspect @capturingIndicies}")
      super
    match: (request) ->
      console.log("matching regexp_matcher! #{@regexp}")
      if request.path[0]? and match = request.path[0].match(@regexp)
        return unless match[0].length == request.path[0].length
        console.log("successfully matched regexp_matcher! #{@regexp} #{util.inspect match[0]}")
        request = request.clone()
        @addVariables(request, match)
        request.path.shift()
        super(request)
    addVariables: (request, match) ->
      console.log("----> #{util.inspect @varIndicies}")
      for v in @varIndicies when v?
        console.log(util.inspect v)
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
      console.log("matching #{@type}! #{@regexp}")
      if request.path.length > 0
        console.log("request path is non trivial")
        wholePath = request.wholePath()
        console.log("whole path is #{wholePath}")
        if match = wholePath.match(@regexp)
          return unless match.index == 0
          console.log("omg, match #{util.inspect match}")
          request = request.clone()
          @addVariables(request, match)
          console.log("#{match.index} + #{match[0].length}: #{match.index + match[0].length}")
          console.log(util.inspect wholePath.slice(match.index + match[0].length, wholePath.length))
          request.path = request.splitPath(wholePath.slice(match.index + match[0].length, wholePath.length))
          console.log(util.inspect request.path)
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
      console.log("matched! #{@route.name} #{@partial} #{util.inspect request.path}" )
      if @partial or request.path.length == 0
        console.log("... path matched")
        @addDestination(request)
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
          console.log "creating query .... #{base} #{params}"
          query += encodeURIComponent(base).replace(/%20/g, '+')
          query += '='
          query += encodeURIComponent(params).replace(/%20/g, '+')
          query += '&'
      query
    url: (params) ->
      path = undefined
      for pathIdx in [(@pathSet.length - 1)..0]
        path = @pathSet[pathIdx].url(params)
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
      console.log("Path? #{util.inspect(path)} #{path?}")
      unless path?
        path = url.parse(@underlyingRequest.url).pathname
      decodeURI(path)
    splitPath: (path) ->
      console.log("splitting path #{util.inspect path} #{util.inspect @decodedPath(path).split('/')}")
      decodedPath = @decodedPath(path)
      splitPath = if decodedPath == '/' then [] else decodedPath.split('/')
      splitPath.shift() if splitPath[0] == ''
      console.log("splitPath: #{util.inspect(splitPath)}")
      splitPath
    clone: ->
      c = new Request()
      c.path = @path.slice(0, @path.length)
      c.variables = @variables.slice(0, @variables.length)
      c.underlyingRequest = @underlyingRequest
      c.callback = @callback
      c.destinations = @destinations
      c
