require 'redis'
require 'securerandom'

module Flora

  class DeviceManager
  
    include LoggerMethods
    include RedisKeys
    include Conversion
  
    OPTS = {}
  
    attr_reader :redis, :logger

    def initialize(opts=OPTS)
      
      @net_id = opts[:net_id]||0
      @logger = opts[:logger]||NULL_LOGGER
      @redis = opts[:redis]
      @defer = opts[:defer]
      
    end
    
    # Find device by dev_addr
    #
    # @param dev_addr [Integer]
    #
    # @return [nil,Device]
    #
    def lookup_by_addr(dev_addr)
      
      if name = redis.get(rk_dev_addr(dev_addr))
      
        if record = redis.get(rk_eui(name))        
        
          Device.new(record: JSON.from_json(record), logger: logger, redis: redis, defer: @defer)
        
        else

          log_error { "dev_addr #{dev_addr.to_s(16)} does not map to a device record" }
          nil
        
        end
        
      else

        log_debug { "dev_addr #{dev_addr.to_s(16)} not found" }
        nil
          
      end
      
    end
    
    # Find device by dev_eui
    #
    # @param dev_eui [String] 8 byte string
    #
    # @return [nil,Device]
    #
    def lookup_by_eui(dev_eui)
      
      name = [dev_eui].pack("m0")
      
      if record = redis.get(rk_eui(name))
        
        Device.new(record: JSON.from_json(record), logger: logger, redis: redis, defer: @defer)
        
      else
      
        log_debug{"dev_eui #{bytes_to_hex(dev_eui)} not found"}
        nil
      
      end
      
    end
    
    # Load an existing device record
    #
    # If the device already exists it will be replaced. 
    #
    # @param exported [Hash] #export_device export format
    # @param opts [Hash]
    # 
    # @return [Device]
    #
    # @raise [RestoreDeviceError]
    #
    def restore_device(exported, opts=OPTS)
    
      raise RestoreDeviceError.new "exported must be a Hash" unless exported.kind_of? Hash
      raise RestoreDeviceError.new "exported:version is invalid" unless exported['version'].kind_of? Integer
      raise RestoreDeviceError.new "exported:fields is invalid" unless exported['fields'].kind_of? Hash
      
      case exported['version']
      when 0
      
        prefix = "exported:fields:record"
      
        raise RestoreDeviceError.new "#{prefix} is invalid" unless exported['fields']['record'].kind_of? Hash
        
        # only the following keys can be present
        record = exported['fields']['record'].slice(
          "minor",
          "dev_eui",
          "join_eui",
          "dev_addr",
          "join_nonce",
          "dev_nonce",
          "net_id",
          "keys",
          "up_counter",
          "region",
          
          "rx_delay",              
          "rx1_dr_offset",
          "rx2_dr",
          "rx2_freq",
          "adr_ack_limit",
          "adr_ack_delay"
        )
        
        raise RestoreDeviceError.new "#{prefix}:minor is invalid" unless record['minor'].kind_of? Integer
        raise RestoreDeviceError.new "#{prefix}:dev_eui is invalid" unless is_an_eui?(record['dev_eui'])
        raise RestoreDeviceError.new "#{prefix}:join_eui is invalid" unless record['join_eui'].nil? or is_an_eui?(record['join_eui'])
        raise RestoreDeviceError.new "#{prefix}:dev_addr is invalid" unless record['dev_addr'].kind_of? Integer
        raise RestoreDeviceError.new "#{prefix}:join_nonce is invalid" unless record['join_nonce'].kind_of? Integer
        raise RestoreDeviceError.new "#{prefix}:dev_nonce is invalid" unless record['dev_nonce'].nil? or record['dev_nonce'].kind_of? Integer
        raise RestoreDeviceError.new "#{prefix}:net_id is invalid" unless record['net_id'].nil? or record['net_id'].kind_of? Integer
        raise RestoreDeviceError.new "#{prefix}:channel_plan is invalid" unless record['region'].kind_of? String
        raise RestoreDeviceError.new "#{prefix}:up_counter is invalid" unless record['up_counter'].nil? or record['up_counter'].kind_of? Integer
        
        raise RestoreDeviceError.new "#{prefix}:region is unknown" unless Region.by_name(record['region'])
        
        raise RestoreDeviceError.new "#{prefix}:keys is invalid" unless record['keys'].kind_of? Hash
        
        keys = record['keys']
        
        # only the following keys can be present
        strip_except_keys!(keys, 
          "nwk",
          "app",
          "fnwksint",
          "snwksint",
          "nwksenc",
          "jsenc",
          "jsint",
          "apps"
        )
        
        raise RestoreDeviceError.new "#{prefix}:keys:nwk is invalid" unless is_a_key?(keys['nwk'])
        raise RestoreDeviceError.new "#{prefix}:keys:app is invalid" unless keys['app'].nil? or is_a_key?(keys['app'])
        
        # presence of join_eui means device has been joined
        if record['join_eui']
        
          log_debug{"exported record appears to be for a joined device"}
        
          raise RestoreDeviceError.new "#{prefix}:keys:fnwksint is invalid" unless is_a_key?(keys['fnwksint'])
          raise RestoreDeviceError.new "#{prefix}:keys:snwksint is invalid" unless is_a_key?(keys['snwksint'])
          raise RestoreDeviceError.new "#{prefix}:keys:nwksenc is invalid" unless is_a_key?(keys['nwksenc'])
          raise RestoreDeviceError.new "#{prefix}:keys:jsenc is invalid" unless is_a_key?(keys['jsenc'])
          raise RestoreDeviceError.new "#{prefix}:keys:jsint is invalid" unless is_a_key?(keys['jsint'])
          
          if record["minor"] == 0 or is_a_key?(keys['app'])
          
            raise RestoreDeviceError.new "#{prefix}:keys:apps is invalid" unless is_a_key?(keys['apps'])
            
          end
          
        else
        
          log_debug{"exported record appears to be for an unjoined device"}
        
          record.delete("dev_nonce")          
          
          keys.delete("apps")
          keys.delete("fnwksint")
          keys.delete("snwksint")
          keys.delete("nwksenc")
          keys.delete("jsenc")
          keys.delete("jsint")
          
        end
        
        raise RestoreDeviceError.new "exported:fields:nwk_counter is invalid" unless exported['fields']['nwk_counter'].nil? or exported['fields']['nwk_counter'].kind_of? Integer
        raise RestoreDeviceError.new "exported:fields:app_counter is invalid" unless exported['fields']['app_counter'].nil? or exported['fields']['app_counter'].kind_of? Integer
    
        # todo should check if it already exists and handle that
        
        name = record['dev_eui']
        dev_addr = record['dev_addr']
        
        app_counter = exported['fields']['app_counter']
        nwk_counter = exported['fields']['nwk_counter']
        
        # fixme: this leaks keys to the log
        log_debug{"restoring #{JSON.to_json(record)}"}
        
        redis.multi do
        
          redis.set(rk_eui(name), JSON.to_json(record))
          redis.set(rk_app_counter(name), app_counter)
          redis.set(rk_nwk_counter(name), nwk_counter)
          
          redis.del(rk_return_path(name))
          redis.del(rk_uplink_history(name))
          redis.del(rk_adr_setting(name))
          
          redis.set(rk_dev_addr(dev_addr), name)
          
        end
        
        Device.new(record: symbolise(record), redis: redis, defer: @defer, logger: logger)
        
      else
    
        raise RestoreDeviceError.new "exported:version #{exported['version']} is not supported"
      
      end
      
    end
    
    # Export a device record in a format which can later be used with #restore_device
    #
    # @param dev_eui [String]   unique 8 byte identifier
    # @return [Hash]            export format
    #
    # @raise [ExportDeviceError]
    # @raise [JSONError]
    #
    def export_device(dev_eui, opts=OPTS)
      
      raise ExportDeviceError.new "dev_eui must be an 8 byte string" unless dev_eui.kind_of? String and dev_eui.size == 8
      
      name = [dev_eui].pack("m0")
      
      record, nwk_counter, app_counter = redis.multi do
        redis.get(rk_eui(name))
        redis.get(rk_nwk_counter(name))
        redis.get(rk_app_counter(name))
      end
      
      raise ExportDeviceError.new "dev_eui #{bytes_to_hex(dev_eui)} does not exist" unless record
      
      record = JSON.from_json(record, symbols: false)
      
      record.delete('join_request_frame')
      record.delete('data_frame')
      
      {
        "version" => 0,
        "exported_at" => Time.now,
        "fields" => {
          "record" => record,
          "nwk_counter" => nwk_counter.to_i,
          "app_counter" => app_counter.to_i
        }
      }
      
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
    def create_device(args=OPTS)
      
      dev_eui = args[:dev_eui]
      app_key = args[:app_key]
      nwk_key = args[:nwk_key]
      dev_addr = args[:dev_addr]
      
      minor = args[:minor]||0
      
      join_nonce = args[:join_nonce]||0
      region = args[:region]||:EU_863_870
      
      rx_delay = args[:rx_delay]
      rx1_dr_offset = args[:rx1_dr_offset]
      rx2_dr = args[:rx2_dr]
      rx2_freq = args[:rx2_freq]
      adr_ack_limit = args[:adr_ack_limit]
      adr_ack_delay = args[:adr_ack_delay]
      
      nwk_counter = 0
      app_counter = 0
      
      raise CreateDeviceError.new "args:dev_eui is mandatory" unless dev_eui
      raise CreateDeviceError.new "args:dev_eui must be an 8 byte string" unless dev_eui.kind_of? String and dev_eui.size == 8
      
      raise CreateDeviceError.new "args:dev_addr is mandatory" unless dev_addr
      raise CreateDeviceError.new "args:dev_addr must be an integer in the range 0..(2**25-1)" unless (0..2**25-1).include? dev_addr
      
      raise CreateDeviceError.new "args:nwk_key is mandatory" unless nwk_key
      raise CreateDeviceError.new "args:nwk_key must be a 16 byte string" unless nwk_key.kind_of? String and nwk_key.size == 16
      
      raise CreateDeviceError.new "args:minor if defined must be an integer in the range 0..1" unless (0..1).include? minor
      
      raise CreateDeviceError.new "args:app_key if defined must be a 16 byte string" unless app_key.nil? or (app_key.kind_of? String and app_key.size == 16)
      
      raise CreateDeviceError.new "args:join_nonce if defined must be an integer in the range 0..(2**24-1)" unless (0..2**24-1).include? join_nonce
      
      if minor == 0 and app_key
        log_info { "note that args:app_key is not required args:minor is 0 (and therefore discarded)" }
        app_key = nil
      end
      
      Region.by_name(region).tap do |cls|
      
        raise CreateDeviceError.new "region: '#{region}' is unknown" unless cls
      
        begin
          cls.new(
            rx_delay: args[:rx_delay],
            rx1_dr_offset: args[:rx1_dr_offset],
            rx2_dr: args[:rx2_dr],
            rx2_freq: args[:rx2_freq],
            adr_ack_limit: args[:adr_ack_limit],
            adr_ack_delay: args[:adr_ack_delay]
          )
        rescue
          raise CreateDeviceError.new "fine tuning options not accepted for this region"
        end
      
      end
      
      name = [dev_eui].pack("m0")
      
      record = {
        region: region,
        dev_addr: dev_addr,
        dev_eui: name,              
        keys: {
          app: (app_key ? [app_key].pack("m0") : nil), 
          nwk: [nwk_key].pack("m0")
        },         
        join_nonce: join_nonce,        
        minor: minor,
        
        rx_delay: rx_delay,
        rx1_dr_offset: rx1_dr_offset,
        rx2_dr: rx2_dr,
        rx2_freq: rx2_freq,
        adr_ack_limit: adr_ack_limit,
        adr_ack_delay: adr_ack_delay,
        
        gw_join_channels: []
               
      }.compact
      
      if redis.exists(rk_dev_addr(dev_addr))
      
        raise CreateDeviceError.new "args:dev_addr #{dev_addr.to_s(16)} already exists"
      
      end

      if redis.setnx(rk_eui(name), JSON.to_json(record)) == false
      
        raise CreateDeviceError.new "args:dev_eui #{bytes_to_hex(dev_eui)} already exists"
      
      end

      dev_addr_ok, nwk_counter_ok, app_counter_ok = redis.multi do
        
        redis.setnx(rk_dev_addr(dev_addr), name)
        redis.setnx(rk_nwk_counter(name), nwk_counter)
        redis.setnx(rk_app_counter(name), app_counter)

      end
      
      if !dev_addr_ok or !nwk_counter_ok or !app_counter_ok
      
        redis.del(rk_eui(name))
      
        raise CreateDeviceError.new "could not set #{rk_dev_addr(dev_addr)}" unless dev_addr_ok
        raise CreateDeviceError.new "could not set #{rk_nwk_counter(nwk_counter)}" unless nwk_counter_ok
        raise CreateDeviceError.new "could not set #{rk_app_counter(app_counter)}" unless app_counter_ok
      
      end
      
      Device.new(record: record, redis: redis, defer: @defer, logger: logger) 
    
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
    def destroy_device(dev_eui, opts=OPTS)
      
      name = [dev_eui].pack("m0")
      
      dev_addr = nil
      
      if record = redis.get(rk_eui(name))
        begin
          record = JSON.from_json(record)
          dev_addr = record[:dev_addr]||opts[:dev_addr]      
        rescue JSONError
          dev_addr = opts[:dev_addr]
        end          
      else
        dev_addr = opts[:dev_addr]
      end
      
      redis.multi do
        redis.del(rk_dev_addr(dev_addr))
        redis.del(rk_eui(name))
        redis.del(rk_nwk_counter(name))
        redis.del(rk_app_counter(name))
      end
      
      self
      
    end
    
    def is_an_eui?(value)
      value.kind_of?(String) and value.unpack("m").first.size == 8
    end
    
    def is_a_key?(value)
      value.kind_of?(String) and value.unpack("m").first.size == 16
    end
    
    def strip_except_keys!(hash, *keys)
      hash.delete_if do |k,v|
        not(keys.include?(k))
      end
    end
    
    private :is_an_eui?, :is_a_key?, :strip_except_keys!
    
  end

end
