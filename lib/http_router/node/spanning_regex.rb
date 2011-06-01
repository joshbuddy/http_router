class HttpRouter
  class Node
    class SpanningRegex < Regex
      def to_code(pos)
        indented_code(pos, "
          whole_path = r#{pos}.joined_path
          if match = #{@matcher.inspect}.match(whole_path) and match.begin(0).zero?
            r#{pos.next} = r#{pos}.clone\n" <<
            (@splitting_indicies || []).map { |s| "r#{pos.next}.params << URI.unescape(match[#{s}]).split(/\\//)\n" }.join <<
            @capturing_indicies.map { |c| "r#{pos.next}.params << URI.unescape(match[#{c}])\n" }.join << "
            remaining_path = whole_path[match[0].size + (whole_path[match[0].size] == ?/ ? 1 : 0), whole_path.size]
            r#{pos.next}.path = remaining_path.split('/')
            #{node_to_code(pos.next)}
          end
        ")
      end
    end
  end
end