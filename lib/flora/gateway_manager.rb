module Flora

  class GatewayManager
  
    include LoggerMethods
    include RedisKeys
  
    attr_reader :redis, :logger
  
    def initialize(**opts)
    
      @redis = opts[:redis]
      @logger = opts[:logger]||NULL_LOGGER
    
    end
    
    def lookup_by_eui(eui)
    
      name = [eui].pack("m0")
      
      if record = redis.get(rk_gw_eui(name))
      
        Gateway.new(record: JSON.from_json(record), logger: logger, redis: redis)
      
      end
      
    end
    
    def create_gateway(**args)
    
      config = SX1301Config.by_name(args[:config])
      
      raise CreateGatewayError.new "gw_config: #{args[:config]} is unknown" unless config
    
      name = [args[:eui]].pack("m0")
    
      record = {
        
        eui: name,
        config: args[:config],
        auth_token: args[:token]        

      }.compact
    
      redis.set(rk_gw_eui(name), JSON.to_json(record))
      
      Gateway.new(record: record)

    end
  
  end

end
