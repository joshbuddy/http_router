class HttpRouter
  class Node
    class Destination < Node
      attr_reader :blk, :allow_partial, :param_names
      
      def initialize(router, parent, blk, allow_partial)
        @blk, @allow_partial = blk, allow_partial
        super(router, parent)
      end

      def usable?(other)
        other.class == self.class && other.allow_partial == allow_partial && other.blk == blk
      end

      def to_code
        path = blk
        path_ivar = :"@path_#{router.next_counter}"
        inject_root_ivar(path_ivar, blk)
        "#{"if request.path_finished?" unless @allow_partial}
          catch(:pass) do
            #{"if request.path.size == 1 && request.path.first == '' && (request.rack_request.head? || request.rack_request.get?) && request.rack_request.path_info[-1] == ?/
              response = ::Rack::Response.new
              response.redirect(request.rack_request.path_info[0, request.rack_request.path_info.size - 1], 302)
              throw :success, response.finish
            end" if @router.redirect_trailing_slash?}

            #{"if request.path.empty?#{" or (request.path.size == 1 and request.path.first == '')" if @router.ignore_trailing_slash?}" unless @allow_partial}
              if request.perform_call
                env = request.rack_request.dup.env
                env['router.request'] = request
                env['router.params'] ||= {}
                #{"env['router.params'].merge!(Hash[#{path.param_names.inspect}.zip(request.params)])" if path.dynamic?}
                #{@allow_partial ? "router.rewrite_partial_path_info(env, request)" : "router.rewrite_path_info(env, request)" }
                response = @router.process_destination_path(#{path_ivar}, env)
                router.pass_on_response(response) ? throw(:pass) : throw(:success, response)
              else
                throw :success, Response.new(request, #{path_ivar})
              end
            #{"end" unless @allow_partial}
          end
        #{"end" unless @allow_partial}"
      end
    end
  end
end