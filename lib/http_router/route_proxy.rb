class HttpRouter
  class RouteProxy
    attr_reader :route

    def initialize(route)
      @route = route
      @router = route.router
    end

    def method_missing(name, *args, &blk)
      if @route.respond_to?(name)
        @route.send(name, *args, &blk)
        self
      else
        super
      end
    end

    def path
      @route.path_for_generation
    end

    def path=(path)
      if path.respond_to?(:[]) and path[/[^\\]\*$/]
        @route.match_partially = true
        @route.path_for_generation = path[0..path.size - 2]
      else
        @route.path_for_generation = path
      end
    end

    def name(name = nil)
      name ? route.name = name : route.name
    end

    def process_opts(opts)
      if opts[:conditions]
        opts.merge!(opts[:conditions])
        opts.delete(:conditions)
      end
      opts.each do |k, v|
        if @route.respond_to?(:"#{k}=")
          @route.send(:"#{k}=", v)
        elsif @route.respond_to?(:"add_#{k}")
          send(:"add_#{k}", v)
        else
          @route.add_match_with(k => v)
        end
      end
    end

    def to(dest = nil, &dest_block)
      @route.dest = dest || dest_block || raise("you didn't specify a destination")
      if @route.dest.respond_to?(:url_mount=)
        urlmount = UrlMount.new(@route.path_for_generation, @route.default_values || {}) # TODO url mount should accept nil here.
        urlmount.url_mount = @router.url_mount if @router.url_mount
        @route.dest.url_mount = urlmount
      end
      self
    end

    def get
      @route.add_request_method "GET"
      self
    end

    def post
      @route.add_request_method "POST"
      self
    end

    def put
      @route.add_request_method "PUT"
      self
    end

    def delete
      @route.add_request_method "DELETE"
      self
    end

    def redirect(path, status = 302)
      raise ArgumentError, "Status has to be an integer between 300 and 399" unless (300..399).include?(status)
      to { |env|
        params = env['router.params']
        response = ::Rack::Response.new
        response.redirect(eval(%|"#{path}"|), status)
        response.finish
      }
    end

    # Sets the destination of this route to serve static files from either a directory or a single file.
    def static(root)
      @route.match_partially = true if File.directory?(root)
      to File.directory?(root) ?
        ::Rack::File.new(root) :
        proc {|env| 
          env['PATH_INFO'] = File.basename(root)
          ::Rack::File.new(File.dirname(root)).call(env)
        }
    end
  end
end