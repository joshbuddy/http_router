class HttpRouter
  class Node
    class SpanningRegex < Regex
      def to_code
        params_count = @ordered_indicies.size
        "whole_path#{depth} = request.joined_path
        if match = #{@matcher.inspect}.match(whole_path#{depth}) and match.begin(0).zero?
          original_path#{depth} = request.path.dup
          " << param_capturing_code << "
          remaining_path = whole_path#{depth}[match[0].size + (whole_path#{depth}[match[0].size] == ?/ ? 1 : 0), whole_path#{depth}.size]
          request.path = remaining_path.split('/')
          #{node_to_code}
          request.path = original_path#{depth}
          request.params.slice!(#{-params_count.size}, #{params_count})
        end
        "
      end
    end
  end
end