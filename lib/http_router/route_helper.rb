class HttpRouter
  module RouteHelper
    def path
      @route.path_for_generation
    end

    def path=(path)
      @original_path = path
      if path.respond_to?(:[]) and path[/[^\\]\*$/]
        @match_partially = true
        @path_for_generation = path[0..path.size - 2]
      else
        @path_for_generation = path
      end
    end

    def name(name = nil)
      if name
        self.name = name
        self
      else
        @name
      end
    end

    def add_default_values(hash)
      @default_values ||= {}
      @default_values.merge!(hash)
    end

    def add_match_with(matchers)
      @match_with ||= {}
      @match_with.merge!(matchers)
    end

    def add_other_host(hosts)
      (@other_hosts ||= []).concat(hosts)
    end

    def add_path(path)
      (@paths ||= []) << path
    end

    def add_request_method(methods)
      @request_methods ||= Set.new
      methods = [methods] unless methods.is_a?(Array)
      methods.each do |method|
        method = method.to_s.upcase
        unless Route::VALID_HTTP_VERBS.include?(method)
          raise ArgumentError, "Unsupported HTTP request method: #{method}"
        end
        @request_methods << method
      end
    end

    def process_opts(opts)
      if opts[:conditions]
        opts.merge!(opts[:conditions])
        opts.delete(:conditions)
      end
      opts.each do |k, v|
        if respond_to?(:"#{k}=")
          send(:"#{k}=", v)
        elsif respond_to?(:"add_#{k}")
          send(:"add_#{k}", v)
        else
          add_match_with(k => v)
        end
      end
    end

    def to(dest = nil, &dest_block)
      @dest = dest || dest_block || raise("you didn't specify a destination")
      if @dest.respond_to?(:url_mount=)
        urlmount = UrlMount.new(@path_for_generation, @default_values || {}) # TODO url mount should accept nil here.
        urlmount.url_mount = @router.url_mount if @router.url_mount
        @dest.url_mount = urlmount
      end
      self
    end

    # Creates helper methods for each supported HTTP verb.
    Route::VALID_HTTP_VERBS_WITHOUT_GET.each do |request_method|
      define_method(request_method.downcase) do
        add_request_method(request_method)
        self
      end
    end

    def get
      add_request_method("GET")
      add_request_method("HEAD")
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
      @match_partially = true if File.directory?(root)
      to File.directory?(root) ?
        ::Rack::File.new(root) :
        proc {|env| 
          env['PATH_INFO'] = File.basename(root)
          ::Rack::File.new(File.dirname(root)).call(env)
        }
    end
  end
end