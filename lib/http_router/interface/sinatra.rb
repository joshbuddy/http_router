require 'http_router'

class HttpRouter
  module Interface
    class Sinatra

      def initialize
        ::Sinatra.send(:include, Extension)
      end

      module Extension

        def self.registered(app)
          app.send(:include, Extension)
        end

        def self.included(base)
          base.extend ClassMethods
        end

        def generate(name, *params)
          self.class.generate(name, *params)
        end

        private
          def route!(base=self.class, pass_block=nil)
            if base.router and match = base.router.recognize(@request)
              if match.matched?
                @block_params = match.params
                (@params ||= {}).merge!(match.params_as_hash)
                pass_block = catch(:pass) do
                  route_eval(&match.route.dest)
                end
              else
                route_eval { 
                  match.headers.each{|k,v| response[k] = v}
                  status match.status
                }
              end
            end

            # Run routes defined in superclass.
            if base.superclass.respond_to?(:router)
              route! base.superclass, pass_block
              return
            end

            route_eval(&pass_block) if pass_block

            route_missing
          end

        module ClassMethods

          def new(*args, &bk)
            configure! unless @_configured
            super(*args, &bk)
          end

          def route(verb, path, options={}, &block)
            name = options.delete(:name)

            define_method "#{verb} #{path}", &block
            unbound_method = instance_method("#{verb} #{path}")
            block = block.arity.zero? ?
              proc { unbound_method.bind(self).call } :
              proc { unbound_method.bind(self).call(*@block_params) }

            invoke_hook(:route_added, verb, path, block)

            route = router.add(path)

            route.matching(options[:matching]) if options.key?(:matching)

            route.request_method(verb)
            route.host(options[:host]) if options.key?(:host)
            
            route.name(name) if name
            route.to(block)
            route
          end

          def router
            @router ||= HttpRouter.new
            block_given? ? yield(@router) : @router
          end

          def generate(name, *params)
            router.url(name, *params)
          end

          def reset!
            router.reset!
            super
          end

          def configure!
            configure :development do
              error 404 do
                content_type 'text/html'

                (<<-HTML).gsub(/^ {17}/, '')
                <!DOCTYPE html>
                <html>
                <head>
                  <style type="text/css">
                  body { text-align:center;font-family:helvetica,arial;font-size:22px;
                    color:#888;margin:20px}
                  #c {margin:0 auto;width:500px;text-align:left}
                  </style>
                </head>
                <body>
                  <h2>Sinatra doesn't know this ditty.</h2>
                  <div id="c">
                    Try this:
                    <pre>#{request.request_method.downcase} '#{request.path_info}' do\n  "Hello World"\nend</pre>
                  </div>
                </body>
                </html>
                HTML
              end
              error 405 do
                content_type 'text/html'

                (<<-HTML).gsub(/^ {17}/, '')
                <!DOCTYPE html>
                <html>
                <head>
                  <style type="text/css">
                  body { text-align:center;font-family:helvetica,arial;font-size:22px;
                    color:#888;margin:20px}
                  #c {margin:0 auto;width:500px;text-align:left}
                  </style>
                </head>
                <body>
                  <h2>Sinatra sorta knows this ditty, but the request method is not allowed.</h2>
                </body>
                </html>
                HTML
              end
            end

            @_configured = true
          end
        end # ClassMethods
      end # Extension
    end # Sinatra
  end # Interface
end # HttpRouter