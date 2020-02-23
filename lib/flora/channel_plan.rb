module Flora

  module ChannelPlan
  
    PLANS = []
    
    def self.plan(name)
      PLANS.detect{|n|n.name == name}
    end
  
    PLANS << EU_863_870.new("default_eu", 
      rx2_dr: 2,
      mask: (Array.new(8){false} + Array.new(8){true}),
      channels: [      
        {
          ch_index:   3,
          freq:       867100000,
          min_dr:     0,
          max_dr:     5
        },
        {
          ch_index:   4,
          freq:       867300000,
          min_dr:     0,
          max_dr:     5
        },
        {
          ch_index:   5,
          freq:       867500000,
          min_dr:     0,
          max_dr:     5
        },
        {
          ch_index:   6,
          freq:       867700000,
          min_dr:     0,
          max_dr:     5
        },
        {
          ch_index:   7,
          freq:       867900000,
          min_dr:     0,
          max_dr:     5
        }        
      ]      
    )
  
    PLANS << US_902_928.new("default_us", 
      # mask all except second group of 8 channels plus second 500KHz channel
      mask: Array.new(8){true} + Array.new(8){false} + Array.new(48){true} + [true, false] + Array.new(6){true}
    )
    
    PLANS << AU_915_928.new("default_au", 
      # mask all except second group of 8 channels plus second 500KHz channel
      mask: Array.new(8){true} + Array.new(8){false} + Array.new(48){true} + [true, false] + Array.new(6){true}
    )
    
  end

end
