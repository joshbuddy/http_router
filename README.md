# HTTP Router

## What is it?

This is an HTTP router for use in either a web framework, or on it's own using Rack. It takes a set of routes and attempts to find the best match for it. Take a look at the examples directory for how you'd use it in the Rack context.

## Features

* Ordered route resolution.
* Supports variables, and globbing, both named and unnamed.
* Regex support for variables.
* Request condition support.
* Partial matches.
* Supports interstitial variables (e.g. /my-:variable-brings.all.the.boys/yard) and unnamed variable /one/:/two
* Very fast and small code base (~1,000 loc).
* Sinatra via https://github.com/joshbuddy/http_router_sinatra

## Usage

Please see the examples directory for a bunch of awesome rackup file examples, with tonnes of commentary. As well, the rdocs should provide a lot of useful specifics and exact usage.

### `HttpRouter.new`

Takes the following options:

* `:default_app` - The default #call made on non-matches. Defaults to a 404 generator.
* `:ignore_trailing_slash` - Ignores the trailing slash when matching. Defaults to true.
* `:middleware` - Perform matching without deferring to matched route. Defaults to false.

### `#add(name, options)`

Maps a route. The format for variables in paths is:
  :variable
  *glob

Everything else is treated literally. Optional parts are surrounded by brackets. Partially matching paths have a trailing `*`. Optional trailing slash matching is done with `/?`.

As well, you can escape the following characters with a backslash: `( ) : *`

Once you have a route object, use `HttpRouter::Route#to` to add a destination and `HttpRouter::Route#name` to name it.

e.g.

```ruby
  r = HttpRouter.new
  r.add('/test/:variable(.:format)').name(:my_test_path).to {|env| [200, {}, "Hey dude #{env['router.params'][:variable]}"]}
  r.add('/test').redirect("http://www.google.com/")
  r.add('/static').static('/my_file_system')
```

As well, you can support regex matching and request conditions. To add a regex match, use `matching(:id => /\d+/)`.
To match on a request condition you can use `condition(:request_method => %w(POST HEAD))` or more succinctly `request_method('POST', 'HEAD')`.

There are convenience methods HttpRouter#get, HttpRouter#post, etc for each request method.

Routes will not be recognized unless `#to` has been called on it.

### `#url(name or route, *args)`

Generates a route. The args can either be a hash, a list, or a mix of both.

### `#call(env or Rack::Request)`

Recognizes and dispatches the request.

### `#recognize(env or Rack::Request)`

Only performs recognition.

