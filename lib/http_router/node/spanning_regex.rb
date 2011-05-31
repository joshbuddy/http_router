class HttpRouter
  class Node
    class SpanningRegex < Regex
      def to_code(pos)
        "
whole_path = request#{pos}.joined_path
if match = #{@matcher.inspect}.match(whole_path) and match.begin(0).zero?
  request#{pos.next} = request#{pos}.clone
  #{"#{@splitting_indicies.inspect}.each { |idx| request#{pos.next}.params << URI.unescape(match[idx]).split(/\\\//) }" if @splitting_indicies}
  #{@capturing_indicies.inspect}.each { |idx| request#{pos.next}.params << URI.unescape(match[idx]) }
  remaining_path = whole_path[match[0].size + (whole_path[match[0].size] == ?/ ? 1 : 0), whole_path.size]
  request#{pos.next}.path = remaining_path.split('/')
  #{node_to_code(pos.next)}
end
        "
      end
    end
  end
end