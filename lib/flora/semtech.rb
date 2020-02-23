module Flora

  module Semtech
  
    class Message
    
      @@version = 2
      @type = nil
      @@subs = []
    
      def self.inherited(klass)
        if self == Message
          @@subs << klass
        else
          superclass.inherited(klass)
        end
      end    
        
      def self.subs
        @@subs
      end
    
      def ===(other)
        self.class == other
      end

      def self.===(other)
        self == other.class
      end
    
      def self.type
        @type
      end
      
      def self.version
        @@version
      end
      
      def type
        self.class.send(__method__)
      end
      
      def version
        self.class.send(__method__)
      end
    
      attr_reader :token
    
      def initialize
        raise "abstract class"
      end
    
      def encode
        [version, token, type].pack("CS>C")
      end
      
    end
    
    class PushData < Message
    
      @type = 0
      
      attr_reader :eui, :obj
      
      def initialize(token, eui, obj)
        @token = token
        @eui = eui
        @obj = obj
      end
      
      def encode
        super.concat(eui, JSON.to_json(obj))
      end
    
      def self.decode(token, s)
      
        eui = s.strip!(8)
        

        self.new(token, eui, obj)
      end
    
    end
    
    class PushAck < Message
      
      @type = 1
      
      def initialize(token)
        @token = token
      end
      
    end
    
    class PullData < Message
    
      @type = 2
      
      def initialize(token, eui)
        @token = token
        @eui = eui
      end
      
      def encode
        super.concat(eui)
      end
      
    end
    
    class PullResp < Message
      
      @type = 3
      
      def initialize(token, event)
        @token = token
        @obj = {
          txpk: {
            imme: false,
            tmst: event.tmst,
            freq: event.freq / 1000000.0,
            rfch: 0,
            powe: event.power.to_i,
            modu: "LORA",
            datr: "SF#{event.sf}BW#{event.bw/1000}",
            codr: "4/5",
            size: event.data.size,
            data: [event.data].pack("m0"),
            ipol: true
          }
        } 
      end
      
      def encode
        super << JSON.to_json(@obj)
      end
      
    end

    class PullAck < Message
      
      @type = 4
      
      def initialize(token)
        @token = token
      end
      
    end
  
    class TXAck < Message
      
      @type = 5
      
      attr_reader :eui, :obj
      
      def initialize(token, eui, obj)
        @token = token||rand(0..0xffff)
        @eui = eui
        @obj = obj
      end
      
      def encode
        super.concat(eui, JSON.to_json(obj))
      end
      
    end
  
    class Parser
    
      include LoggerMethods
    
      DATR_TO_SF_BW = [125000, 250000, 500000].inject({}) do |result, bw|
      
        (6..12).to_a.each do |sf|
        
          result["SF#{sf}BW#{bw/1000}"] = [sf, bw]
        
        end
      
        result
      
      end
      
      def datr_to_sf_bw(datr)
        DATR_TO_SF_BW[datr]
      end    
    
      def initialize(**opts)
        @logger = opts[:logger]
        @lookup = Message.subs.select{|f|f.type}.map{|f|[f.type, f]}.to_h
      end
      
      def decode(input)
      
        input = input.dup
      
        time_now = Time.now
      
        if input.size < 12
          log_debug "input too short"
          return
        end
      
        obj = nil
        
        version, token, type = input.slice!(0,4).unpack("CS>C")
        eui = input.slice!(0,8)
        
        if version != Message.version
          log_debug "unexpected version"
          return
        end
        
        #cls = @lookup[type]
        
        case type
        when PushAck.type
          log_debug("decoded #{PushAck.new(token)}")
        when PullAck.type
          log_debug("decoded #{PullAck.new(token)}")
        when TXAck.type
          log_debug("decoded #{TXAck}")
        when PullResp.type
          log_debug("decoded #{PullResp}")
        when PullData.type
          log_debug("decoded #{PullData}")

          yield(PullAck.new(token))
          yield(GatewayPullEvent.new(gw_eui: [eui].pack("m0"))) 

        when PushData.type
          
          begin            
            obj = JSON.from_json(input)                      
          rescue JSONError => ex
            log_debug("JSON parsing error: #{ex}")
            return
          end
          
          yield(PushAck.new(token))
            
          if not obj.kind_of? Hash
            log_debug "invalid JSON object"
            return
          end
            
          if obj[:rxpk]
          
            if not obj[:rxpk].kind_of? Array
              log_debug "invalid JSON object"
              return
            end
            
            obj[:rxpk].each do |pk|

              if pk[:stat] == -1
                log_debug "discarding bad CRC"
                next
              end
            
              data = pk[:data].unpack("m").first
              
              f = FrameDecoder.new(logger: @logger).decode(data)
              
              if f.nil?
                log_debug "invalid LoRaWAN frame"    
                next
              end

              sf, bw = datr_to_sf_bw(pk[:datr])

              if sf.nil? or bw.nil?
                log_debug "invalid datr setting"    
                next
              end
              
              event = GatewayUpEvent.new(
                token: token,
                rx_time: time_now,
                gw_eui: [eui].pack("m0"),
                frame: f,
                data: data,
                tmst: pk[:tmst].to_i,
                freq: (pk[:freq] * 1000000).to_i,
                sf: sf, 
                bw: bw,
                rssi: pk[:rssi],  
                snr: pk[:lsnr],  
              )
                  
              yield(event)

            end
            
          end
            
        else
          log_debug("unknown type")
        end
      
        nil
      
      end
    
    end  
    
  end
      
end
