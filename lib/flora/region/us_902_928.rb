require_relative 'us_902_928_helpers'

module Flora  
  
  class US_902_928 < Region
    
    include US_902_928_Helpers
    
    CHANNELS = Array.new(64).map.with_index do |v, i|
      ChannelDef.new(i, 902300000 + (i*200000), 0, 3, false)
    end + Array.new(8).map.with_index do |v,i|
      ChannelDef.new(i+64, 903000000 + (i*1600000), 4, 4, false)
    end
    
    DOWN_CHANNELS = Array.new(8).map.with_index do |v, i|
      ChannelDef.new(i, 923300000 + (i*600000), 8, 13, false)
    end
    
    RX2_FREQ = 923300000
    RX2_DR = 8
    
    # x: rx1_dr_offset
    # y: upstream dr
    RX = [
      [10,9, 8, 8 ],
      [11,10,9, 8 ],
      [12,11,10,9 ],
      [13,12,11,10],
      [13,13,12,11]         
    ]
    
    UP_RATES = {
      [10, 125000] => 0,
      [9, 125000] => 1,
      [8, 125000] => 2,
      [7, 125000] => 3,
      [8, 500000] => 4
    }
    
    DOWN_RATES = {
      [12, 500000] => 8,
      [11, 500000] => 9,
      [10, 500000] => 10,
      [9, 500000] => 11,
      [8, 500000] => 12,
      [7, 500000] => 13    
    }
    
    RATE_TO_SF_BW = [
      [10, 125000],
      [9, 125000],
      [8, 125000],
      [7, 125000],
      [8, 500000],
      nil,
      nil,
      nil,
      [12, 500000],
      [11, 500000],
      [10, 500000],
      [9, 500000],
      [8, 500000],
      [7, 500000]      
    ] 
    
    # mandatory 16 entry array
    LNS_RATE_LIST = [
      [10,125000,0],
      [9,125000,0],
      [8,125000,0],
      [7,125000,0],
      [8,500000,0],
      
      # filler
      [7,125000,0],
      [7,125000,0],
      [7,125000,0],
      
      # downstreams
      [12, 500000,1],
      [11, 500000,1],
      [10, 500000,1],
      [9, 500000,1],
      [8, 500000,1],
      [7, 500000,1],
      
      # filler
      [7,125000,0],
      [7,125000,0]      
    ]

    include US_902_928_Helpers
    
  end

end
