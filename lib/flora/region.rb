module Flora

  ChannelDef = Struct.new(:ch_index, :freq, :min_dr, :max_dr, :masked)
  ExchangeParams = Struct.new(:up, :rx1, :rx2, keyword_init: true)
  RadioParams = Struct.new(:freq, :chan, :sf, :bw, :rate, :delay, keyword_init: true)
  ADRMask = Struct.new(:ch_mask_cntl, :ch_mask)

  class Region

    @@subs = []

    def self.inherited(klass)
      if self == Region
        @@subs << klass      
      else
        superclass.inherited(klass)
      end        
    end

    def self.by_name(name)
      name = name.to_sym    
      result = @@subs.detect{|region|region.region == name}
      raise ArgumentError.new "region '#{name}' is unknown" unless result
      result
    end
    
    def self.lns_drs
      self::LNS_RATE_LIST
    end
    
    JOIN_ACCEPT_DELAY = 5
    
    RX_DELAY = 1
    
    RX1_DR_OFFSET = 0
    RX2_DR = 0
    RX2_FREQ = 0
    
    ADR_ACK_LIMIT = 64
    ADR_ACK_DELAY = 32

    # this method is only used on initialisation, channels are considered
    # fixed after this object has been created
    #
    #
    def add_channel(freq, min_dr, max_dr)      
      if chan = channels.detect{|chan|chan.freq == freq}
        chan.masked = false
      elsif chan = channels.detect{|chan|chan.freq == 0}
        chan.freq = freq
        chan.masked = false
      end
    end
    
    def mask_all
      channels.each{|chan| chan.masked = true}
    end
    
    def initialize(**settings)      
    
      raise "abstract class" if self.class == Region
    
      @rx_delay = settings[:rx_delay]||self.class::RX_DELAY
      @rx1_dr_offset = settings[:rx1_dr_offset]||self.class::RX1_DR_OFFSET
      @rx2_dr = settings[:rx2_dr]||self.class::RX2_DR
      @rx2_freq = settings[:rx2_freq]||self.class::RX2_FREQ
      @adr_ack_limit = settings[:adr_ack_limit]||ADR_ACK_LIMIT
      @adr_ack_delay = settings[:adr_ack_delay]||ADR_ACK_DELAY
      
      @channels = self.class::CHANNELS.dup
      
      if settings[:channels] and not(settings[:channels].empty?)

        mask_all()
      
        settings[:channels].each do |chan|
        
          add_channel(chan[:freq], chan[:rates].min, chan[:rates].max)
          
        end
      
      end
      
      generate_freq_to_channel
      
    end

    attr_reader :rx2_dr, :rx1_dr_offset, :rx2_freq, :adr_ack_limit, :adr_ack_delay
    attr_reader :channels

    def rx_delay
      @rx_delay == 0 ? 1 : @rx_delay
    end
    
    def ja_delay
      JOIN_ACCEPT_DELAY
    end

    def rx1_dr(up_rate)
      if row = self.class::RX[up_rate]
        row[rx1_dr_offset]
      end
    end

    def self.region
      name.split("::").last.to_sym
    end

    def region
      self.class.region
    end
    
    def freq_to_channel(freq)
      @freq_to_channel[freq]
    end

    # create frequency to channel const time lookup
    def generate_freq_to_channel
      @freq_to_channel = channels.map{|c|[c.freq, c] if c}.compact.to_h      
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
  
  Dir[FLORA_ROOT.join("flora", "region", "*.rb")].each do |f|
    require f
  end
  
end
