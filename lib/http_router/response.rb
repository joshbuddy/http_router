class HttpRouter
  module Response
    def self.matched(*args)
      Matched.new(*args)
    end

    def self.unmatched(*args)
      Unmatched.new(*args)
    end

    private
    class Unmatched < Struct.new(:status, :headers)
      def matched?
        false
      end
    end

    class Matched < Struct.new(:path, :params, :matched_path, :remaining_path)
      attr_reader :params_as_hash, :route

      def initialize(path, params, matched_path, remaining_path = nil)
        raise if matched_path.nil?
        super
        path.splitting_indexes and path.splitting_indexes.each{|i| params[i] = params[i].split('/')}
        @params_as_hash = path.variable_names.zip(params).inject({}) {|h, (k,v)| h[k] = v; h }
      end

      def matched?
        true
      end

      def route
        path.route
      end

      def dest
        route.dest
      end
      alias_method :destination, :dest

      def partial_match?
        route.partially_match?
      end
    end
  end
end
