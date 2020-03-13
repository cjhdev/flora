module Flora

  class ID6
  
    COMPACT = "::"
  
    def self.decode(input)
    
      groups = input.split(COMPACT)
      
      return unless (1..2).include? groups.size
      
      # convert group(s) into an array of 16bit integers
      result = groups.map do |group|
        group.split(":").inject([]) do |result, word|
          result << word.to_i(16)
          return if result.last > (2**16-1)
          result
        end
      end
      
      # there should be no more than 4 subgroups
      return if result.sum{|s|s.size} > 4
      
      if result.size == 1
        if input.strip[/::$/]
          result = result.first + Array.new(4 - result.first.size){0}        
        elsif result.first.size != 4
          return
        else
          result = result.first
        end      
      elsif result.first.empty?
        result = Array.new(4 - result.last.size){0} + result.last
      else
        result = result.first + Array.new(4 - result.first.size - result.last.size){0} + result.last
      end
      
      self.new(result.pack("S>*"))
      
    end
      
    attr_reader :value
    
    def initialize(value)
      @value = value
    end
    
    def to_s
      value.bytes.each_slice(2).map{|v|"%x" % ((v.first << 8) + v.last)}.join(":").sub(/^((0:0:0:)|(0:0:))/,COMPACT).sub(/:0:0:/,COMPACT).sub(/((:0:0:0)|(:0:0))$/, COMPACT) 
    end        
    
  end

end
