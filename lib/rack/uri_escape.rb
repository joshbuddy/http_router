unless Rack::Utils.respond_to?(:query_escape)
  module Rack
    module Utils
      def uri_escape(s)
        s.to_s.gsub(/([^:\/?\[\]\-_~\.!\$&'\(\)\*\+,;=@a-zA-Z0-9]+)/n) {
          '%'<<$1.unpack('H2'*$1.size).join('%').upcase
        }
      end
      module_function :uri_escape
    end
  end
end

unless Rack::Utils.respond_to?(:uri_escape)
  module Rack
    module Utils
      def uri_escape(s)
        s.to_s.gsub(/([^:\/?\[\]\-_~\.!\$&'\(\)\*\+,;=@a-zA-Z0-9]+)/n) {
          '%'<<$1.unpack('H2'*$1.size).join('%').upcase
        }
      end
      module_function :uri_escape
    end
  end
end

unless Rack::Utils.respond_to?(:uri_escape!)
  module Rack
    module Utils
      def uri_escape!(s)
        s.to_s.gsub!(/([^:\/?\[\]\-_~\.!\$&'\(\)\*\+,;=@a-zA-Z0-9]+)/n) {
          '%'<<$1.unpack('H2'*$1.size).join('%').upcase
        }
      end
      module_function :uri_escape!
    end
  end
end

unless Rack::Utils.respond_to?(:uri_unescape)
  module Rack
    module Utils
      def uri_unescape(s)
        gsub(/((?:%[0-9a-fA-F]{2})+)/n){
          [$1.delete('%')].pack('H*')
        }
      end
      module_function :uri_unescape
    end
  end
end
