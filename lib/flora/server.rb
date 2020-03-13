require 'securerandom'

module Flora

  class Server

    PID = SecureRandom.uuid
    
    include LoggerMethods

    attr_reader :gw, :defer, :dm, :net_id, :logger

    # create new server instance
    #
    # options are passed via a block which is evaluated within ServerDSL
    #
    def self.create(name=nil, &block)
    
      name = File.basename(caller_locations.first.absolute_path, ".rb") if name.nil?
      
      settings = {}
      settings = ServerDSL.new(&block) if block
      
      self.new(**settings.to_h)
    
    end

    # This will normally be called by ::create with all the default parameters
    # filled in
    #
    # @param opts [Hash]
    #
    # @option opts [Logger] :logger
    # @option opts [Integer] :event_queue_depth
    # @option opts [Integer] :num_event_workers
    # @option opts [Proc] :event_handler
    # @option opts [Symbol] :gateway_connector
    #
    #
    def initialize(**opts)
    
      @logger = opts[:logger]||NULL_LOGGER
      @redis = opts[:redis]      
      @defer = DeferQueue.new(logger: @logger)      
      @dm = DeviceManager.new(**opts.merge(defer: @defer, redis: @redis))
      @gm = GatewayManager.new(**opts.merge(defer: @defer, redis: @redis))
      
      raise ArgumentError.new "redis object must be provided" if @redis.nil?
      
      opts[:event_queue_depth].tap do |param|
        raise ArgumentError.new "event_queue_depth must be an integer" unless param.kind_of? Integer
        raise ArgumentError.new "event_queue_depth be greater than zero" unless param > 0
      end
      
      opts[:num_event_workers].tap do |param|
        raise unless param.kind_of? Integer
        raise unless param > 0
      end
      
      @net_id = opts[:net_id]
      
      @on_event = opts[:on_event]
      
      @on_eui_missing = opts[:on_eui_missing]
      @on_dev_addr_missing = opts[:on_dev_addr_missing]
     
      case opts[:gateway_connector]
      when :semtech    
        
        @gw = UDPConnector.new(**opts) { |event| process_event(event) }
        
      when :lns
      
        @gw = LNSConnector.new(**opts.merge({gw_manager: @gw_manager})) { |event| process_event(event) }
        
      else
      
        raise ArgumentError.new "gateway_connector ':#{opts[:gateway_connector]}' not supported"
      
      end
      
    end
  
    # opens the gateway port and begins processing events
    def start
      if not @gw.running?
        log_info { "starting..." }
        @gw.start
        @defer.start        
      end
    end
    
    # closes the gateway port and finishes processing events
    def stop
      if @gw.running?
        log_info { "stopping..." }
        @gw.stop
        @defer.stop
        log_info { "stopped" }
      end
    end
    
    # start or restart
    def restart
      if @gw.running?
        @gw.restart
      else
        start
      end
    end
    
    # Create a new device on the server
    #
    # @param args    [Hash]
    #
    # @option args [String] :dev_eui unieque 8 byte string (mandatory)
    # @option args [String] :nwk_key 16 byte string (mandatory)
    # @option args [String] :app_key 16 byte string (optional)
    # @option args [Integer] :version LoRaWAN minor version ((0..1) where 1 is default)
    # 
    def create_device(**args)
      @dm.create_device(**args)
    end
    
    # Restore an existing device to the server
    #
    def restore_device(exported, **args)
      @dm.restore_device(exported, **args)
    end
    
    # Remove device from server
    #
    def destroy_device(dev_eui, **args)
      @dm.destroy_device(dev_eui, **args)
    end
    
    # Export a device record
    #
    def export_device(dev_eui, **opts)
      @dm.export_device(dev_eui, **opts)
    end
    
    # Remove a device from the server
    #
    # @param dev_eui [String] unique 8 byte string
    def remove_device(dev_eui)
      @dm.destroy(dev_eui)
    end
    
    def create_gateway(**args)
      @gm.create_gateway(**args)        
    end

    def process_event(event)
    
      case event
      when GatewayUpEvent
      
        case event.frame
        when JoinRequest
        
          device = dm.lookup_by_eui(event.frame.dev_eui)
        
          if device.nil? and @on_eui_missing
          
            device = @on_eui_missing.call(event, self)
            
            raise ArgumentError.new "on_eui_missing must return nil or an instance of Device" unless device.nil? or device.kind_of? Device
            
          end
          
          if device
            
            device.process_join_request(event) do |response|
              
              case response
              when GatewayDownEvent           
              
                gw.send_downstream(response)
                 
              when ActivationEvent, DeviceUpdateEvent
                
                @on_event.call(response, self) if @on_event
                 
              end
              
            end
            
          end
        
        when RejoinRequest
        
          # do nothing for now
        
        when DataUnconfirmedUp, DataConfirmedUp
        
          device = dm.lookup_by_addr(event.frame.dev_addr)
        
          if device.nil? and @on_dev_addr_missing
          
            device = @on_dev_addr_missing.call(event, self)
            
            raise ArgumentError.new "on_dev_addr_missing must return nil or an instance of Device" unless device.nil? or device.kind_of? Device
            
          end
        
          if device
          
            device.process_data_up(event) do |response|
            
              case response
              when GatewayDownEvent
              
                gw.send_downstream(response)

              when DataUpEvent, DeviceUpdateEvent
              
                @on_event.call(response, self) if @on_event
              
              end
            
            end
        
          end
        
        end
        
      end
        
    end

  end
  
end
