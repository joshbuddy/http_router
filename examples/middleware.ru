require 'http_router'

use(HttpRouter, :middleware => true) {
  add('/test').name(:test)
  add('/:variable').name(:var)
  add('/more/*glob').name(:glob)
  add('/get/:id').matching(:id => /\d+/).name(:get)
}

run proc {|env|
  [
    200,
    {'Content-type' => 'text/plain'},
    [<<-HEREDOC
We matched? #{env['router.response'] && env['router.response'].matched? ? 'yes!' : 'no'}      
Params are #{env['router.response'] && env['router.response'].matched? ? env['router.response'].params_as_hash.inspect : 'we had no params'}
That was fun
    HEREDOC
    ]
  ]
}

# crapbook-pro:polleverywhere joshua$ curl http://127.0.0.1:3000/hi
# We matched? yes!      
# Params are {:variable=>"hi"}
# That was fun
# crapbook-pro:polleverywhere joshua$ curl http://127.0.0.1:3000/test
# We matched? yes!      
# Params are {}
# That was fun
# crapbook-pro:polleverywhere joshua$ curl http://127.0.0.1:3000/hey
# We matched? yes!      
# Params are {:variable=>"hey"}
# That was fun
# crapbook-pro:polleverywhere joshua$ curl http://127.0.0.1:3000/more/fun/in/the/sun
# We matched? yes!      
# Params are {:glob=>["fun", "in", "the", "sun"]}
# That was fun
# crapbook-pro:polleverywhere joshua$ curl http://127.0.0.1:3000/get/what
# We matched? no      
# Params are we had no params
# That was fun
# crapbook-pro:polleverywhere joshua$ curl http://127.0.0.1:3000/get/123
# We matched? yes!      
# Params are {:id=>"123"}
# That was fun
