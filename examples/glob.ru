require 'http_router'

run HttpRouter.new {
  get('/*glob').to { |env| [200, {'Content-type' => 'text/plain'}, ["My glob is\n#{env['router.params'][:glob].map{|v| " * #{v}\n"}.join}"]]}
}

# $ curl http://127.0.0.1:3000/123/345/123
# => My glob is
# =>  * 123
# =>  * 345
# =>  * 123