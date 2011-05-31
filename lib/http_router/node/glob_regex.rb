class HttpRouter
  class Node
    class GlobRegex < SpanningRegex
      def add_params(request)
        @capturing_indicies.each { |idx| request.params << URI.unescape(match[idx].split('/')) }
      end

      def to_code(pos)
        "
whole_path = request#{pos}.joined_path
if match = #{@matcher.inspect}.match(whole_path) and match.begin(0).zero?
request#{pos.next} = request#{pos}.clone
#{@capturing_indicies.inspect}.each { |idx| request#{pos.next}.params << URI.unescape(match[idx].split('/')) }
remaining_path = whole_path[match[0].size + (whole_path[match[0].size] == ?/ ? 1 : 0), whole_path.size]
request#{pos.next}.path = remaining_path.split('/')
#{super(pos.next)}
end
        "
      end
    end
  end
end