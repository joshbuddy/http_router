class HttpRouter
  class OptionalCompiler
    attr_reader :paths
    def initialize(path)
      @start_index = 0
      @end_index = 1
      @paths = [""]
      @chars = path.split('')
      while !@chars.empty?
      case @chars.first[0]
        when ?(
          @chars.shift and double_paths
        when ?)
          @chars.shift and half_paths
        when ?\\ 
          if @chars[1] == ?( || @chars[1] == ?)
            @chars.shift 
          else
            add_to_current_set(@chars.shift)
          end
          add_to_current_set(@chars.shift)
        else
          add_to_current_set(@chars.shift)
        end
      end
      @paths
    end
    
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