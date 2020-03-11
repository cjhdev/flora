module Flora

  class MacCommandDecoder
  
    include LoggerMethods
  
    def initialize(**opts)
      @logger = opts[:logger]||NULL_LOGGER
      @up_lookup = MacCommand.subs.select{|c|c.upstream}.map{|c|[c.tag,c]}.to_h
      @down_lookup = MacCommand.subs.select{|c|c.upstream}.map{|c|[c.tag,c]}.to_h
    end
    
    def decode_up(input)
    
      s = InputCodec.new(input)
      
      result = []
      
      while s.remaining > 0 do
      
        tag = s.get_u8
        
        cls = @up_lookup[tag]

        log_debug { "unknown MAC command tag #{tag}" } unless cls
        break unless cls
        
        obj = cls.decode(s)
        
        log_debug {"could not decode MAC command tag #{tag}"} unless obj
        break unless obj
        
        result << obj        
        
      end
      
      result
      
    end
    
    def decode_down(input)      
    end
  
  end

end
