class HttpRouter
  class Node
    class SpanningRegex < Regex
      def to_code
        params_count = (@splitting_indicies || []).size + @capturing_indicies.size
        "whole_path#{depth} = request.joined_path
        if match = #{@matcher.inspect}.match(whole_path#{depth}) and match.begin(0).zero?
          original_path#{depth} = request.path.dup
          " <<
          (@splitting_indicies || []).map { |s| "request.params << match[#{s}].split(/\\//)\n" }.join <<
          @capturing_indicies.map { |c| "request.params << match[#{c}]\n" }.join << "
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