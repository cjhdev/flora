module Flora
  
  # A number of methods are used to provide information in LNS protocol
  # format. This format is probably not useful in any other situations.
  #
  #
  class Gateway
  
    include LoggerMethods
  
    def initialize(**opts)
      
      @logger = opts[:logger]||NULL_LOGGER
      @redis = opts[:redis]
      
      @record = opts[:record]
      
      raise unless @record
      
      raise unless @record[:eui]
      raise unless @record[:config]
      
      @config = SX1301Config.by_name(@record[:config])
      
    end
    
    def nocca
      @record[__method__]||false
    end
    
    def nodc
      @record[__method__]||false
    end
    
    def nodwell
      @record[__method__]||false
    end
    
    def auth_token
      @record[__method__]
    end
    
    def eui
      @record[__method__].unpack("m")
    end
    
    # LNS format of acceptable datarates
    def drs
      @config.drs
    end
    
    # LNS format frequency range
    def freq_range
      @config.tx_freq_range
    end
    
    # LNS format
    def hwspec
      "sx1301/#{@config.config.size}"
    end
    
    # LNS format
    def region_code
      @config.region_code
    end
    
    def region
      @config.region
    end
    
    # LNS format
    def sx1301_conf
      @config.config
    end
    
    # LNS format
    def join_eui
      [[0,2**64-1]]
    end
    
    def rx_channels
      @config.channels
    end
    
  end

end
