class HttpRouter
  class Node
    class Path < Node
      attr_reader :route, :param_names, :dynamic, :path
      alias_method :dynamic?, :dynamic
      def initialize(router, parent, route, path, param_names = [])
        @route, @path, @param_names, @dynamic = route, path, param_names, !param_names.empty?
        @route.add_path(self)

        raise AmbiguousVariableException, "You have duplicate variable names present: #{duplicates.join(', ')}" if param_names.uniq.size != param_names.size
        super router, parent
        router.uncompile
      end

      def hashify_params(params)
        @dynamic && params ? Hash[param_names.zip(params)] : {}
      end

      def to_code
        path_ivar = inject_root_ivar(self)
        "#{"if !callback && request.path.size == 1 && request.path.first == '' && (request.rack_request.head? || request.rack_request.get?) && request.rack_request.path_info[-1] == ?/
          response = ::Rack::Response.new
          response.redirect(request.rack_request.path_info[0, request.rack_request.path_info.size - 1], 302)
          return response.finish
        end" if router.redirect_trailing_slash?}

        #{"if request.#{router.ignore_trailing_slash? ? 'path_finished?' : 'path.empty?'}" unless route.match_partially}
          if callback
            request.called = true
            callback.call(Response.new(request, #{path_ivar}))
          else
            env = request.rack_request.dup.env
            env['router.request'] = request
            env['router.params'] ||= {}
            #{"env['router.params'].merge!(Hash[#{param_names.inspect}.zip(request.params)])" if dynamic?}
            @router.rewrite#{"_partial" if route.match_partially}_path_info(env, request)
            response = @router.process_destination_path(#{path_ivar}, env)
            return response unless router.pass_on_response(response)
          end
        #{"end" unless route.match_partially}"
      end

      def usable?(other)
        other == self
      end

      def inspect_label
        "Path: #{path.inspect} for route #{route.name || 'unnamed route'} to #{route.dest.inspect}"
      end

      def duplicates
        param_names.group_by { |e| e }.select { |k, v| v.size > 1 }.map(&:first)
      end
    end
  end
end