module Flora  

  module US_902_928_Helpers
  
    def rx1_chan(freq)
      (freq_to_channel(freq).ch_index.modulo(8))
    end
    
    def rx1_freq(freq)
      DOWN_CHANNELS[rx1_chan(freq)].freq      
    end
  
    def cflist
      [channels.map{|b|b.masked ? "1" : "0"}.join].pack("b*").concat("\x00\x00\x00\x00\x00\x00\x01")
    end
  
    def full_adr_mask      
      [channels.map{|m|m.masked ? "1" : "0"}.join].pack("b*").concat("\x00").unpack("S<*").map.with_index do |m,i| 
        ADRMask.new(i, m)        
      end
    end
    
    def adr_mask
      
      grouping = ADRMask.new(8, 0)
      mixed = []
      
      channels.each_slice(8).with_index do |bank, i|
        
        break if i == 4
        
        case bank.count{|chan|chan.masked}
        when 8
          if channels[64 + i].masked
            grouping.ch_mask |= (1 << i)
          else
            mixed << i
          end
        when 0        
          unless channels[64 + i].masked
            grouping.ch_mask |= (1 << i)
          else
            mixed << i
          end          
        else
          mixed << i
        end
        
      end
      
      # be lazy, return either the perfectly grouped plan, or the full mask
      if mixed.empty?
        
        [grouping]
        
      else
      
        full_adr_mask()
      
      end
      
    end
  
  end
  
end
