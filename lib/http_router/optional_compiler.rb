class HttpRouter
  class OptionalCompiler
    attr_reader :paths
    def initialize(path)
      @start_index, @end_index = 0, 1
      @paths, @chars = [""], path.split('')
      until @chars.empty?
      case @chars.first[0]
        when ?( then @chars.shift and double_paths
        when ?) then @chars.shift and half_paths
        when ?\\ 
          @chars[1] == ?( || @chars[1] == ?) ? @chars.shift : add_to_current_set(@chars.shift)
          add_to_current_set(@chars.shift)
        else
          add_to_current_set(@chars.shift)
        end
      end
      @paths
    end

    private
    def add_to_current_set(c)
      (@start_index...@end_index).each { |path_index| @paths[path_index] << c }
    end
    
    # over current working set, double @paths
    def double_paths 
      (@start_index...@end_index).each { |path_index| @paths << @paths[path_index].dup }
      @start_index = @end_index
      @end_index = @paths.size
    end

    def half_paths
      @start_index -= @end_index - @start_index
    end
  end
end