module Flora

  class EU_863_870 < Region
      
    CHANNELS = [
    
      ChannelDef.new(0, 868100000, 0, 5, false),
      ChannelDef.new(1, 868300000, 0, 5, false),
      ChannelDef.new(2, 868500000, 0, 5, false),
      
      ChannelDef.new(3, 0, 0, 7, true),
      ChannelDef.new(4, 0, 0, 7, true),
      ChannelDef.new(5, 0, 0, 7, true),
      ChannelDef.new(6, 0, 0, 7, true),
      ChannelDef.new(7, 0, 0, 7, true),
      
      ChannelDef.new(8, 0, 0, 7, true),
      ChannelDef.new(9, 0, 0, 7, true),
      ChannelDef.new(10, 0, 0, 7, true),
      ChannelDef.new(11, 0, 0, 7, true),
      ChannelDef.new(12, 0, 0, 7, true),
      ChannelDef.new(13, 0, 0, 7, true),
      ChannelDef.new(14, 0, 0, 7, true),
      ChannelDef.new(15, 0, 0, 7, true)
    ]
    
    RX2_DR = 0
    RX2_FREQ = 869525000
    
    # x: rx1_dr_offset
    # y: upstream dr
    RX = [
      [0,0,0,0,0,0],
      [1,0,0,0,0,0],
      [2,1,0,0,0,0],
      [3,2,1,0,0,0],
      [4,3,2,1,0,0],
      [5,4,3,2,1,0],
      [6,5,4,3,2,1],
      [7,6,5,4,3,2]    
    ]
    
    UP_RATES = {
      [12,125000] => 0,
      [11,125000] => 1,
      [10,125000] => 2,
      [9,125000] => 3,
      [8,125000] => 4,
      [7,125000] => 5,
      [7,250000] => 6    
    }
    
    DOWN_RATES = UP_RATES
    
    RATE_TO_SF_BW = [
      [12,125000],
      [11,125000],
      [10,125000],
      [9,125000],
      [8,125000],
      [7,125000],
      [7,250000]  
    ]
    
    # mandatory 16 entry array
    LNS_RATE_LIST = [
      [12,125000,0],
      [11,125000,0],
      [10,125000,0],
      [9,125000,0],
      [8,125000,0],
      [7,125000,0],
      [7,250000,0],
      [0,50000,0],
      
      # filler
      [7,125000,0],
      [7,125000,0],
      [7,125000,0],
      [7,125000,0],
      [7,125000,0],
      [7,125000,0],
      [7,125000,0],
      [7,125000,0]    
    ]
    
    def rx1_freq(freq)
      freq
    end
    
    def cflist()
      
      s = OutputCodec.new
      
      channels.each do |chan|
      
        next if chan.ch_index < 3
        break if chan.ch_index > 7
        
        s.put_u24(chan.freq/100)
      
      end
        
      s.put_u8(0).output

    end
    
    def adr_mask      
      [channels.map{|m|m.masked ? "1" : "0"}.join].pack("b*").unpack("S<").map do |m|
        ADRMask.new(0, m)
      end
    end
    
  end

end
