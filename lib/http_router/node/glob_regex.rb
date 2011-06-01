class HttpRouter
  class Node
    class GlobRegex < SpanningRegex
      def to_code
        "whole_path = request.joined_path
          if match = #{@matcher.inspect}.match(whole_path) and match.begin(0).zero?
            original_path = request.path.dup\n" << 
          @capturing_indicies.map { |c| "request.params << URI.unescape(match[#{c}].split(/\\//))\n" }.join << "
          remaining_path = whole_path[match[0].size + (whole_path[match[0].size] == ?/ ? 1 : 0), whole_path.size]
          request.path = remaining_path.split('/')
          #{super}
          request.path = original_path
          request.params.slice!(#{-@capturing_indicies.size}, #{@capturing_indicies.size})
        end
          "
      end
    end
  end
end