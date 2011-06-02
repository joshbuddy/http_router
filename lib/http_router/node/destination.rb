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
            #{"if request.path.empty?#{" or (request.path.size == 1 and request.path.first == '')" if @router.ignore_trailing_slash?}" unless @allow_partial}
              if request.perform_call
                env = request.rack_request.dup.env
                env['router.params'] ||= {}
                #{"env['router.params'].merge!(Hash[#{path.param_names.inspect}.zip(request.params)])" if path.dynamic?}
                #{@allow_partial ? "
                  env['PATH_INFO'] = \"/\#{request.path.join('/')}\"
                  env['SCRIPT_NAME'] += request.rack_request.path_info[0, request.rack_request.path_info.size - env['PATH_INFO'].size]" : 
                  "env['PATH_INFO'] = ''
                  env['SCRIPT_NAME'] += request.rack_request.path_info"
                }
                response = @router.process_destination(#{path_ivar}.route.dest, env)
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