module Flora

  ChannelDef = Struct.new(:ch_index, :freq, :min_dr, :max_dr)

  ExchangeParams = Struct.new(:up, :rx1, :rx2, keyword_init: true)
  RadioParams = Struct.new(:freq, :chan, :sf, :bw, :rate, :delay, keyword_init: true)

  class Region

    JOIN_ACCEPT1_DELAY = 5
    JOIN_ACCEPT2_DELAY = 6
    
    RX1_DELAY = 1
    RX2_DELAY = 2
    
    RX1_DR_OFFSET = 0
    RX2_DR = 0
    RX2_FREQ = 0
    
    ADR_ACK_LIMIT = 64
    ADR_ACK_DELAY = 32

    def initialize(name, **settings)      
      @name = name
      @rx_delay = settings[:rx_delay]||self.class::RX1_DELAY
      @rx1_dr_offset = settings[:rx1_dr_offset]||self.class::RX1_DR_OFFSET
      @rx2_dr = settings[:rx2_dr]||self.class::RX2_DR
      @rx2_freq = settings[:rx2_freq]||self.class::RX2_FREQ
      @adr_ack_limit = settings[:adr_ack_limit]||ADR_ACK_LIMIT
      @adr_ack_delay = settings[:adr_ack_delay]||ADR_ACK_DELAY
      @channels = self.class::CHANNELS.dup
      @mask = self.class::MASK.dup
      if settings[:mask]
        raise TypeError.new "mask must be an array" unless settings[:mask].kind_of? Array
        raise ArgumentError.new "mask is wrong size for region (got #{settings[:mask].size} expecting #{@mask.size})" if settings[:mask].size != @mask.size
        @mask = settings[:mask]
      end      
      generate_freq_to_channel
    end

    attr_reader :name
    attr_reader :rx2_dr, :rx1_dr_offset, :rx2_freq, :adr_ack_limit, :adr_ack_delay
    attr_reader :channels

    def rx_delay
      @rx_delay == 0 ? 1 : @rx_delay
    end
    
    def ja_delay
      JOIN_ACCEPT1_DELAY
    end

    def rx1_dr(up_rate)
      if row = self.class::RX[up_rate]
        row[rx1_dr_offset]
      end
    end

    def region
      self.class.name.split("::").last
    end
    
    def freq_to_channel(freq)
      @freq_to_channel[freq]
    end

    # create frequency to channel const time lookup
    def generate_freq_to_channel
      @freq_to_channel = @channels.map{|c|[c.freq, c]}.to_h      
    end
    
    def sf_bw_to_rate_up(*sf_bw)
      self.class::UP_RATES[sf_bw]
    end
    
    def sf_bw_to_rate_down(*sf_bw)
      self.class::DOWN_RATES[sf_bw]
    end
    
    def rate_to_sf_bw(rate)
      self.class::RATE_TO_SF_BW[rate]    
    end
    
    # convert upstream parameters into everything you will need to know
    def exchange_params(freq, sf, bw)
      
      up = RadioParams.new
      rx1 = RadioParams.new
      rx2 = RadioParams.new
      
      ## upstream
      
      up.freq = freq
      up.sf = sf
      up.bw = bw
      up.rate = sf_bw_to_rate_up(sf, bw)
      up.chan = freq_to_channel(freq).ch_index
      
      return if up.rate.nil? or up.chan.nil?
      
      ## rx1
      
      rx1.freq = rx1_freq(freq)
      rx1.rate = rx1_dr(up.rate)
      
      rx1.sf, rx1.bw = rate_to_sf_bw(rx1.rate)
      
      ## rx2
      
      rx2.freq = rx2_freq
      rx2.rate = rx2_dr
      
      rx2.sf, rx2.bw = rate_to_sf_bw(rx2.rate)
    
      ## bundle
    
      ExchangeParams.new(
        up: up,
        rx1: rx1,        
        rx2: rx2
      )
      
    end

  end
  
  class EU_863_870 < Region
    
    CHANNELS = [
      ChannelDef.new(0, 868100000, 0, 5),
      ChannelDef.new(1, 868300000, 0, 5),
      ChannelDef.new(2, 868500000, 0, 5)
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
    
    MASK = Array.new(16){false}
    
    def initialize(name, **settings)
      super        
      settings[:channels].each do |chan|        
        raise ArgumentError.new "cannot allocate ch_index less than 3" if chan[:ch_index] < 3
        raise ArgumentError.new "cannot allocate ch_index greater than 15" if chan[:ch_index] > 15        
        @channels[chan[:ch_index]] = ChannelDef.new(chan[:ch_index], chan[:freq].to_i, chan[:min_dr].to_i, chan[:max_dr].to_i)        
      end if settings[:channels]      
      generate_freq_to_channel
    end
    
    def rx1_freq(freq)
      freq
    end
    
    def cflist()
      
      s = OutputCodec.new
      
      5.times do |i|
        
        ch_index = i+3
        
        if chan = @channels[ch_index]
          s.put_u24(chan.freq/100)
        else
          s.put_u24(0)
        end
        
      end
      
      s.put_u8(0).output

    end
    
  end
  
  class US_902_928 < Region
    
    CHANNELS = Array.new(64).map.with_index do |v, i|
      ChannelDef.new(i, 902300000 + (i*200000), 0, 3)
    end + Array.new(8).map.with_index do |v,i|
      ChannelDef.new(i+64, 903000000 + (i*1600000), 4, 4)
    end
    
    DOWN_CHANNELS = Array.new(8).map.with_index do |v, i|
      ChannelDef.new(i, 923300000 + (i*600000), 8, 13)
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
    
    MASK = Array.new(72){false}
    
    def rx1_chan(freq)
      (freq_to_channel(freq).ch_index.modulo(8))
    end
    
    def rx1_freq(freq)
      DOWN_CHANNELS[rx1_chan(freq)].freq      
    end
    
    def cflist
      [@mask.map{|b|b ? "1" : "0"}.join].pack("b#{@mask.size}") + "\x00\x00\x00\x00\x00\x00\x01"
    end
      
  end
  
  class AU_915_928 < Region
    
    CHANNELS = Array.new(64).map.with_index do |v, i|
      ChannelDef.new(i, 915200000 + (i*200000), 0, 5)
    end + Array.new(8).map.with_index do |v,i|
      ChannelDef.new(i+64, 915900000 + (i*1600000), 4, 4)
    end
    
    DOWN_CHANNELS = Array.new(8).map.with_index do |v, i|
      ChannelDef.new(i, 923300000 + (i*600000), 8, 13)
    end
    
    RX2_FREQ = 923300000
    RX2_DR = 8
    
    # x: rx1_dr_offset
    # y: upstream dr
    RX = [
      [8,8,8,8,8,8],
      [9,8,8,8,8,8],
      [10,9,8,8,8,8],
      [11,10,9,8,8,8],
      [12,11,10,9,8,8],
      [13,12,11,10,9,8],
      [13,13,12,11,10,9]    
    ]
    
    UP_RATES = {
      [12, 125000] => 0,
      [11, 125000] => 1,
      [10, 125000] => 2,
      [9, 125000] => 3,
      [8, 125000] => 4,
      [7, 125000] => 5,
      [8, 500000] => 6    
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
      [12, 125000],
      [11, 125000],
      [10, 125000],
      [9, 125000],
      [8, 125000],
      [7, 125000],
      [8, 500000],
      nil,
      [12, 500000],
      [11, 500000],
      [10, 500000],
      [9, 500000],
      [8, 500000],
      [7, 500000]
    ]
    
    MASK = Array.new(72){false}
    
    def rx1_chan(freq)
      (freq_to_channel(freq).ch_index.modulo(8))
    end
    
    def rx1_freq(freq)
      DOWN_CHANNELS[rx1_chan(freq)].freq      
    end
    
    def cflist
      [@mask.map{|b|b ? "1" : "0"}.join].pack("b#{@mask.size}") << "\x00\x00\x00\x00\x00\x00\x01"
    end
    
  end

end
