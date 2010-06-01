require 'http_router'

run HttpRouter.new {
  get('/get/:id').matching(:id => /\d+/).to { |env| [200, {'Content-type' => 'text/plain'}, ["id is #{Integer(env['router.params'][:id]) * 2} * 2\n"]]}
}

# crapbook-pro:~ joshua$ curl http://127.0.0.1:3000/get/123
# id is 246 * 2
# crapbook-pro:~ joshua$ curl http://127.0.0.1:3000/get/asd
# Not Found
