require 'http_router'
run HttpRouter.new do
  add('/get/:id', :match_with => {:id => /\d+/}) { |env|
    [200, {'Content-type' => 'text/plain'}, ["My id is #{env['router.params'][:id]}, which is a number\n"]]
  }

  # you have post, get, head, put and delete.
  post('/get/:id') { |env|
    [200, {'Content-type' => 'text/plain'}, ["My id is #{env['router.params'][:id]} and you posted!\n"]]
  }

  map('/get/:id') { |env|
    [200, {'Content-type' => 'text/plain'}, ["My id is #{env['router.params'][:id]}\n"]]
  }
end

# $ curl http://127.0.0.1:3000/get/foo
# => My id is foo
# $ curl -X POST http://127.0.0.1:3000/get/foo
# => My id is foo and you posted!
# $ curl -X POST http://127.0.0.1:3000/get/123
# => My id is 123, which is a number
