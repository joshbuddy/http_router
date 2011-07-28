class HttpRouter
  class Node
    class SpanningRegex < Regex
      def to_code
        params_count = @ordered_indicies.size
        whole_path_var = "whole_path#{root.next_counter}"
        "#{whole_path_var} = request.joined_path
        if match = #{@matcher.inspect}.match(#{whole_path_var}) and match.begin(0).zero?
          _#{whole_path_var} = request.path.dup
          " << param_capturing_code << "
          remaining_path = #{whole_path_var}[match[0].size + (#{whole_path_var}[match[0].size] == ?/ ? 1 : 0), #{whole_path_var}.size]
          request.path = remaining_path.split('/')
          #{node_to_code}
          request.path = _#{whole_path_var}
          request.params.slice!(#{-params_count.size}, #{params_count})
        end
        "
      end
    end
  end
end