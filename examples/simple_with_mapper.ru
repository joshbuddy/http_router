require 'http_router'
HttpRouter.override_rack_mapper!

map('/get/:id') { |env|
  [200, {'Content-type' => 'text/plain'}, ["My id is #{env['router.params'][:id]}\n"]]
}

post('/get/:id') { |env|
  [200, {'Content-type' => 'text/plain'}, ["My id is #{env['router.params'][:id]} and you posted!\n"]]
}

# crapbook-pro:~ joshua$ curl http://127.0.0.1:3000/get/123
# My id is 123
# crapbook-pro:~ joshua$ curl -X POST http://127.0.0.1:3000/get/123
# My id is 123 and you posted!
