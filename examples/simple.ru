require 'http_router'

run HttpRouter.new {
  get('/hi').to { |env| [200, {'Content-type' => 'text/plain'}, ["hi!\n"]]}
}

# $ curl http://127.0.0.1:3000/hi
# => hi!
