require 'http_router'

run HttpRouter.new {
  get('/:').to { |env| [200, {'Content-type' => 'text/plain'}, ["my variables are\n#{env['router.params'].inspect}\n"]]}
}

# crapbook-pro:~ joshua$ curl http://127.0.0.1:3000/heyguys
# my variables are
# {:$1=>"heyguys"}