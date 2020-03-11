module Flora

  # This class translates SX1301 style configuration into various useful
  # things like frequency lists, acceptable datarates, and masks.
  #
  # The SX1301 config format is fairly 'loose' however this code exports
  # configurations so the code is not likely to fail, however we might
  # make other devices fail by giving them mad configuration.
  #
  class SX1301Config
  
    @@configs = {}
  
    def self.create(name, **args)
      @@configs[name] = self.new(name, **args)            
    end
  
    def self.by_name(name)
    
      result = @@configs[name]
      
      raise RangeError.new "SX1301 config '#{name}' does not exist" unless result
      
      result
      
    end
  
    attr_reader :name
  
    # @param name [String] unique name of this channel configuration for referencing
    # @param opts [Hash]
    #
    # @option opts [Array<Hash>] :config
    # @option opts [Symbol]      :region   Which region does this plan conform to?
    # @option opts [Arraw<Integer,Integer>] :tx_freq_range the minimum and max 
    #
    def initialize(name, **opts)
      
      @name = name
      @config = opts[:config].dup
      @tx_freq_range = opts[:tx_freq_range]
      
      raise SX3101ConfigError.new "tx_freq_range: is mandatory" unless opts[:tx_freq_range]
      raise SX3101ConfigError.new "tx_freq_range: must be an array of [<min>,<max>]" unless opts[:tx_freq_range].kind_of? Array and opts[:tx_freq_range].size == 2 and opts[:tx_freq_range].first <= opts[:tx_freq_range].last
      
      raise ArgumentError.new "region: must be defined" unless opts[:region]
      
      @region = Region.by_name(opts[:region].to_s)
      
      raise ArgumentError.new "region: '#{opts[:region]}' is unknown" unless @region
      
      @available_channels = available_channels
      
    end
    
    def region
      @region.name
    end
    
    def drs
      @region.lns_drs
    end
    
    def config
      @config
    end
    
    # return available RX channels and their demodulation cability
    #
    # @return [Array] 
    #    
    def channels
      @available_channels
    end
    
    def available_channels
      
      result = []
      
      @config.each do |conf|
      
        conf.each do |k,v|
        
          next unless v[:enabled]
        
          case k
          when /chan_multiSF_([0-9]+)/
            
            radio = config["radio_#{v[:radio]}".to_sym]
            
            raise SX3101ConfigError.new "#{k}: must be associated with a radio" unless radio
            raise SX3101ConfigError.new "#{k}: must have an :if field" unless v[:if]
            
            result << {
              freq: (radio[:freq] + v[:if]).to_i,
              rates: (7..12).map{|v|[v,125000]}.map{|sf_bw|@region.sf_bw_to_rate_up(*sf_bw)}.compact          
            }
            
          when "chan_FSK"
          
            radio = config["radio_#{v[:radio]}".to_sym]
            
            raise SX3101ConfigError.new "#{k}: must be associated with a radio" unless radio
            raise SX3101ConfigError.new "#{k}: must have an :if field" unless v[:if]
          
            result << {
              freq: (radio[:freq] + v[:if]).to_i,              
              rates: [[0,50000]].map{|sf_bw|@region.sf_bw_to_rate_up(*sf_bw)}.compact                        
            }
          
          when "chan_Lora_std"

            radio = config["radio_#{v[:radio]}".to_sym]
            
            raise SX3101ConfigError.new "#{k}: must be associated with a radio" unless radio
            raise SX3101ConfigError.new "#{k}: must have an :if field" unless v[:if]
        
            bw = v[:bandwidth]
            
            raise SX3101ConfigError.new "#{k}: must have :bandwidth field" unless bw
            raise SX3101ConfigError.new "#{k}: :bandwidth field must be in range [125000, 250000, 500000]" unless [125000,250000,500000].include? bw
        
            sf = v[:spread_factor]
            
            raise SX3101ConfigError.new "#{k}: must have :spread_factor field" unless sf
            raise SX3101ConfigError.new "#{k}: :spread_factor field must be in range (7..12)" unless (7..12).include? sf
        
            result << {
              freq: (radio[:freq] + v[:if]).to_i,
              rates: [[sf,bw]].map{|sf_bw|@region.sf_bw_to_rate_up(*sf_bw)}.compact                        
            }
            
          end
          
        end

        result
      
      end
      
    end
    
  end
  
  Dir[FLORA_ROOT.join("flora", "gateway_config", "*.rb")].each do |f|
    require f
  end

end
