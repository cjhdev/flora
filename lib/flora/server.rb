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

    # Create a new device
    #
    # @param args [Hash]
    #
    # @option args [String] :dev_eui          unique 8 byte identifier
    # @option args [Integer] :dev_addr        unique 24 bit integer
    # @option args [String] :nwk_key          16 byte string
    #
    # @option args [String,nil] :app_key      OPTIONAL 16 byte string which when absent enables end-to-end application encryption
    # @option args [Integer,nil] :minor       OPTIONAL LoRaWAN minor version number (0 or 1) (defaults to 0)
    # @option args [Integer,nil] :join_nonce  OPTIONAL insert a non-default join_nonce
    #
    # @option args [String] :region           the region this device implements
    #
    # @option args [Integer,nil] :rx_delay        OPTIONAL
    # @option args [Integer,nil] :rx1_dr_offset   OPTIONAL
    # @option args [Integer,nil] :rx2_dr          OPTIONAL
    # @option args [Integer,nil] :rx2_freq        OPTIONAL
    # @option args [Integer,nil] :adr_ack_limit   OPTIONAL
    # @option args [Integer,nil] :adr_ack_delay   OPTIONAL
    #
    # @return [Device]
    #
    # @raise [CreateDeviceError]
    #
    def create_device(**args)
      @dm.create_device(**args)
    end

    # Restore a previously exported device
    #
    # @param exported [Hash] #export_device export format
    #
    # @return [Device]
    #
    # @raise [RestoreDeviceError]
    #
    def restore_device(exported, **args)
      @dm.restore_device(exported, **args)
    end

    # Remove a device
    #
    # All of the redis keys except the dev_addr mapping are
    # derived from the dev_eui. Normally dev_addr can be derived from
    # dev_eui, but if a dev_addr mapping has been somehow orphaned, it
    # can be removed by passing an explicit opts:dev_addr.
    #
    # @param dev_eui [String] unique 8 byte device identifier
    # @param opts [Hash]
    #
    # @option opts [Integer] :dev_addr scrub this dev_addr mapping as well
    #
    # @return [self]
    #
    def destroy_device(dev_eui, **args)
      @dm.destroy_device(dev_eui, **args)
    end

    # Export a device record in a format which can later be used with #restore_device
    #
    # @param dev_eui [String]   unique 8 byte identifier
    #
    # @return [String]          exported record
    #
    # @raise [ExportDeviceError]
    # @raise [JSONError]
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

          process_event_join(event)

        when RejoinRequest
          # do nothing for now
        when DataUnconfirmedUp, DataConfirmedUp

          process_event_data(event)

        end

      end

    end

    def process_event_join(event)

      device = dm.lookup_by_eui(event.frame.dev_eui)

      if device.nil? and @on_eui_missing
        device = @on_eui_missing.call(event, self)
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
    end

    def process_event_data(event)

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
