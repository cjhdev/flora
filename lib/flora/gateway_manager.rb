module Flora

  class GatewayManager
  
    include LoggerMethods
    include RedisKeys
  
    attr_reader :redis, :logger
  
    def initialize(**opts)
    
      @redis = opts[:redis]
      @logger = opts[:logger]||NULL_LOGGER
    
    end
    
    # @param eui [String] base64 encoded
    # @return [Gateway,nil]
    def lookup_by_eui(eui)
    
      if record = redis.get(rk_gw_lookup(eui))
      
        Gateway.new(record: JSON.from_json(record), logger: logger, redis: redis)
      
      end
      
    end
    
    def create_gateway(**args)
    
      config = SX1301Config.by_name(args[:config])
      
      raise CreateGatewayError.new "gw_config: #{args[:config]} is unknown" unless config
      
      raise CreateGatewayError.new "gw_config:eui must be defined" unless args[:eui] 
      
      name = [args[:eui]].pack("m0")
      
      record = {
        
        eui: name,
        config: args[:config],
        auth_token: args[:auth_token]        

      }.compact
    
      redis.set(rk_gw_lookup(name), JSON.to_json(record))
      
      Gateway.new(record: record)

    end
  
  end

end
