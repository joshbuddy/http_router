require 'http_router'

run HttpRouter.new {
  get('/:variable').to { |env| [200, {'Content-type' => 'text/plain'}, ["my variables are\n#{env['router.params'].inspect}\n"]]}
}

# $ curl http://127.0.0.1:3000/heyguys
# => my variables are
# => {:variable=>"heyguys"}
