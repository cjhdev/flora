require 'socket'
require_relative 'gateway_connector'

module Flora

  class UDPConnector < GatewayConnector

    def next_token
      value = @token
      @token += 1
      value
    end

    FREQ = "freq"
    RSSI = "rssi"
    LSNR = "lsnr"
    TMST = "tmst"
    DATA = "data"
    RXPK = "rxpk"
    DATR = "datr"
    
    PUSH_DATA = 0
    PUSH_ACK = 1
    PULL_DATA = 2
    PULL_RESP = 3
    PULL_ACK = 4
    TX_ACK = 5
    P_VERSION = 2
    
    TYPE_TO_NAME = {
      PUSH_DATA => "PushData",
      PUSH_ACK => "PushAck",
      PULL_DATA => "PullData",
      PULL_RESP => "PullResp",
      PULL_ACK => "PullAck",
      TX_ACK => "TXAck"
    }
    
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
    
      @host = opts[:host]||'localhost'
      @port = opts[:port]||0
      @logger = opts[:logger]||NULL_LOGGER
      @num_workers = opts[:num_gw_workers]||1
      @redis = opts[:redis]
    
      @token = rand(0..(2**16-1))
      @socket = nil
      @running = false      
      @worker = []
      @app = Proc.new do
      
        begin
      
          loop do
            
            input, sender = @socket.recvfrom(1024, 0)

            time_now = Time.now
          
            if input.size < 12
              log_debug{"input too short"}
              next
            end
          
            obj = nil
            
            version, token, type = input.slice!(0,4).unpack("CS>C")
            eui = [input.slice!(0,8)].pack("m0")
            
            if version != P_VERSION
              log_debug{"unexpected version"}
              next
            end
            
            if name = TYPE_TO_NAME[type]
            
              log_debug{"received #{name}"}
              
            else
            
              log_debug{"received unknown message type #{type}"}
              next
              
            end
            
            case type   
            when PUSH_DATA
            
              begin            
                obj = JSON.from_json(input, symbols: false)                      
              rescue JSONError => ex
                log_debug{"JSON parsing error: #{ex}"}
                next
              end
              
              log_debug{"responding with PushAck"}
              send_msg([version, token, PUSH_ACK].pack("CS>C"), sender[3], sender[1])
              
              if not obj.kind_of? Hash
                log_debug{"invalid format"}
              end
              
              next unless obj[RXPK].kind_of? Array
              
              obj[RXPK].each do |pk|

                if pk[RXPK] == -1
                  log_debug{"discarding bad CRC"}
                  next
                end
                
                data = pk[DATA].unpack("m").first
                  
                frame = FrameDecoder.new(logger: @logger).decode(data)
                
                if frame.nil?
                  log_debug{"invalid LoRaWAN frame"}
                  next
                end

                sf, bw = datr_to_sf_bw(pk[DATR])

                if sf.nil? or bw.nil?
                  log_debug{"invalid datr setting"}
                  next
                end

                return_addr = restore_gateway(eui)

                if return_addr.nil?
                  return_addr = {
                    addr: sender[3],
                    port: sender[1]
                  }
                end

                yield(
                  GatewayUpEvent.new(
                    rx_time: time_now,
                    frame: frame,
                    data: data,
                    freq: (pk[FREQ] * 1000000).to_i,
                    sf: sf, 
                    bw: bw,
                    rssi: pk[RSSI],  
                    snr: pk[LSNR],  
                    id: eui,                
                    gw_param: {
                      tmst: pk[TMST].to_i,
                      addr: return_addr[:addr],
                      port: return_addr[:port]
                    }
                  )
                )
                
              end
                     
            when PULL_DATA
              
              save_gateway(eui, sender[3], sender[1])
              
              log_debug{"responding with PullAck"}
              send_msg([version, token, PULL_ACK].pack("CS>C"), sender[3], sender[1])
            
            end
            
          end
         
        # socket was closed
        rescue IOError
        # something else
        rescue => e
          log_error{"caught exception: #{e}: #{e.backtrace.join('\n')}"}
        end
        
        @running = false
      
      end
      
    end
        
    def send_downstream(event)
      
      obj = JSON.to_json(
        {
          txpk: {
            imme: false,
            tmst: event.gw_param[:tmst] + (event.rx_delay * 1000000),
            freq: event.rx_param.rx1.freq / 1000000.0,
            rfch: 0,
            powe: 14, # fixme
            modu: "LORA",
            datr: "SF#{event.rx_param.rx1.sf}BW#{event.rx_param.rx1.bw/1000}",
            codr: "4/5",
            size: event.data.size,
            data: [event.data].pack("m0"),
            ipol: true
          }
        } 
      )
    
      log_debug{"sending PullResp: #{obj}"}
    
      send_msg(
        [P_VERSION, next_token, PULL_RESP].pack("CS>C").concat(obj),        
        event.gw_param[:addr],
        event.gw_param[:port]
      )
      
      self
      
    end
    
    def running?
      @running
    end
    
    def send_msg(msg, addr, port)
      raise "not running" unless @running
      @socket.send(msg, 0, addr, port)
      self
    end
    
    def stop
      if @running
        @socket.close 
        @worker.each(&:join)
        @worker.clear
      end
      self
    end
    
    def start
      if not @running
    
        @socket = UDPSocket.new
        @socket.bind(@host, @port)
        
        @worker = Array.new(@num_workers) do
          Thread.new do
            @app.call
          end
        end
        
        @running = true
          
      end
      self
    end
    
    def restart
      stop
      start
    end
    
    def port
      if @running
        @socket.addr[1]
      else
        nil
      end
    end
    
    def save_gateway(eui, addr, port)
      @redis.set(gw_dl_addr(eui), JSON.to_json({addr: addr, port: port}))
      self
    end
    
    def restore_gateway(eui)
      if record = @redis.get(gw_dl_addr(eui))
        JSON.from_json(record)
      else
        nil
      end
    end
    
    private :send_msg, :datr_to_sf_bw, :save_gateway, :restore_gateway
    
  end

end
