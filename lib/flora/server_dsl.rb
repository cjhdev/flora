module Flora

  class ServerDSL
  
    def initialize(**opts, &block)
      @settings = {
        num_event_workers: 1,
        event_queue_depth: 100,
        net_id: 0       # arbitrary OK for experimental
      }
      @logger = opts[:logger]
      self.instance_exec(self, &block)      
    end
  
    def to_h
      @settings.dup
    end
  
    # called to pass events up to the application
    #
    # @option opts [Integer] :workers   number of worker threads (default 5)
    # @option opts [Integer] :depth     maximum size of queue (default 100)
    #
    def on_event(**opts, &block)
      @settings[:on_event] = block
      @settings[:num_event_workers] = opts[:workers]||5
      @settings[:event_queue_depth] = opts[:depth]||100
      self
    end
    
    # Called when a record for the devEUI is not found
    #
    # The idea is this block can be used to load devices into cache. It's
    # entirely optional.
    #
    # @param block [Block] this is called if the device record cannot be found 
    #                      in Redis. If a record is found elsewhere, this block
    #                      must contain code to add the record to Redis, and
    #                      return an instance of Device if you wish for the join attempt
    #                      to be processed
    #
    def on_eui_missing(**opts, &block)
      @settings[:on_eui_missing] = block
      self
    end
    
    # Called when a record for the devAddr is not found
    #
    # The idea is this block can be used to load devices into cache. It's
    # entirely optional.
    #
    # @param block [Block] this is called if the device record cannot be found 
    #                      in Redis. If a record is found elsewhere, this block
    #                      must contain code to add the record to Redis, and
    #                      return an instance of Device if you wish for the join attempt
    #                      to be processed
    #
    def on_dev_addr_missing(**opts, &block)
      @settings[:on_dev_addr_missing] = block
      self
    end
    
    # specify gateway connector protocol
    #
    # @param type [Symbol]
    #
    # @option opts [Integer] :port
    # @option opts [String] :host
    # @option opts [Integer] :workers number of worker threads (default 5)
    #
    def gateway_connector(type, **opts)
      
      raise TypeError.new "connector type must be symbol" unless type.kind_of? Symbol
      raise ArgumentError.new "connector '#{type}' not supported" unless type == :semtech
      
      @settings[:gateway_connector] = type
      @settings[:port] = opts[:port]||0
      @settings[:host] = opts[:host]||'localhost'
      @settings[:num_gw_workers] = opts[:workers]||5
      
      self
      
    end
    
    # specify net_id of this network server
    #
    # @param value [Integer]
    def net_id(value)
    
      raise TypeError unless value.kind_of? Integer
      raise RangeError unless (0..(2**24-1)).include? value
      
      @settings[:net_id] = value
      
    end
    
    # provide a Logger instance for Flora to log to
    #
    # @param log [Logger] can be any class so long as it implements the same methods as Logger
    #
    def logger(log)
      @settings[:logger] = log
      self
    end
    
    # provide a Redis connection instance
    #
    # Flora cannot run without this
    #
    # @param redis [Redis]
    #
    def redis(conn)
      @settings[:redis] = conn
      self
    end
    
    def on_gateway_lookup(**opts, &block)
      @settings[:on_gateway_lookup] = block
      self
    end
    
  end

end
