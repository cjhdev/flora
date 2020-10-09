require_relative 'gateway_connector'

module Flora
  
  class LNSConnector < GatewayConnector
  
    DNMSG = "dnmsg"
    MSGTYPE = "msgtype"
    VERSION = "version"
    DNTXED = "dntxed"
    JREQ = "jreq"
    UPDF = "updf"
    PROPDF = "propdf"
    REJOIN = "rejoin"
    
    MHDR = "MHdr"
    JOIN_EUI = "JoinEui"
    DEV_EUI = "DevEui"
    DEV_NONCE = "DevNonce"
    MIC = "MIC"
    
    UPINFO = "upinfo"
    FREQ = "Freq"
    RSSI = "rssi"
    SNR = "snr"
    RCTX = "rctx"
    XTIME = "xtime"
    GPSTIME = "gpstime"
    DR = "DR"

    FEATURES = "features"

    DEV_ADDR = "DevAddr"
    FCTRL = "FCtrl"
    FCNT = "FCnt"
    FOPTS = "FOpts"
    FPORT = "FPort"
    FRM_PAYLOAD = "FRMPayload"
    
    ROUTER = "router"
    
    ROUTER_CONFIG = "router_config"
    
    GATEWAY_NOT_EXIST = "gateway not exist"
    
    INFO = "info"
  
    attr_reader :lns_id
    
    def port
      @server.port if @server
    end
  
    def initialize(**opts)
  
      @host = opts[:host]||'localhost'
      @port = opts[:port]||0
      @logger = opts[:logger]||NULL_LOGGER
      @num_workers = opts[:num_gw_workers]||1
      @redis = opts[:redis]
      @gateway_manager = opts[:gw_manager]||GatewayManager.new(**opts)
      
      @token = 0
      
      @lns_id = "::0"
      @net_id = opts[:net_id]||0
      
      @queue = nil
      
      @server = LNSServer.new(**opts) do |msg|
      
        @queue.push(msg)
      
      end
      
      @decoder = FrameDecoder.new(logger: @logger)
      
      @worker = []
      
      @app = -> (ev) do
      
        obj = nil
      
        begin
          obj = JSON.from_json(ev.msg, symbols: false) if ev.respond_to? :msg 
        rescue JSONError
          log_debug{"couldn't parse message"}
          return
        end
      
        log_debug{"received #{ev.msg}"} if ev.respond_to? :msg
      
        case ev
        when LNSInfoMessage
        
          unless obj.kind_of? Hash
            ev.socket.message_and_close(JSON.to_json({error: "invalid message"}))
            return
          end
        
          if obj[ROUTER].nil?          
            ev.socket.message_and_close(JSON.to_json({error: "invalid message"}))
            return
          end
      
          eui = Identifier.parse(obj[ROUTER])
      
          if eui.nil?
            ev.socket.message_and_close(JSON.to_json({error: "invalid router id format"}))
            return
          end
          
          gw_id = eui.to_b64
      
          gw = @gateway_manager.lookup_by_eui(gw_id)
          
          response = nil
          
          if gw
          
            if gw.auth_token.nil? or (ev.socket.auth_token == gw.auth_token)
            
              log_debug{"#{ev.socket.url} (#{obj[ROUTER]}) OK"}
            
              response = {
                router: eui.to_id6,
                muxs: lns_id,
                uri: ev.socket.url.sub("info", gw_id)
              }
              
            else
            
              log_debug{"#{ev.socket.url} (#{obj[ROUTER]}) authentication failure"}
            
              response = {
                router: eui.to_id6,
                error: "authentication failure"
              }
            
            end
            
          else
            
            log_debug{"#{ev.socket.url} (#{obj[ROUTER]}) unknown router"}
            
            # don't leak information?
            response = {
              router: eui.to_id6,
              error: "authentication failure"
            }
          
          end
          
          ev.socket.message_and_close(JSON.to_json(response))
        
        when LNSInfoClose
        
          
        
        when LNSRouterConnect
        
          log_debug{"handling session connect"}
        
          gw_id = ev.socket.name
        
          gw = @gateway_manager.lookup_by_eui(gw_id)
        
          if gw
          
            if (gw.auth_token.nil? or (ev.socket.auth_token == gw.auth_token))
            
              ev.socket.start_websocket              
              
              @redis.set(rk_gw_status(JSON.to_json({gw_id: gw_id, connect_time: ev.rx_time.to_f, update_time: ev.rx_time.to_f})))
            
            else
            
              ev.socket.halt(500)
            
            end
          
          else
          
            ev.socket.halt(404)
          
          end
        
        when LNSRouterMessage

          gw_id = ev.socket.name
        
          gw = @gateway_manager.lookup_by_eui(gw_id)
          
          if gw.nil? or (ev.socket.auth_token != gw.auth_token)
          
            log_debug{"cancel connection"}          
            ev.socket.close
            return
            
          end

          @redis.set(rk_gw_status(gw_id),
            JSON.to_json(
              {
                gw_id: gw_id, 
                connect_time: ev.rx_time.to_f, 
                update_time: ev.rx_time.to_f
              }
            )
          )

          unless obj.kind_of? Hash
            ev.socket.message_and_close(JSON.to_json({error: "invalid message"}))
            return
          end
          
          case obj[MSGTYPE]
          when VERSION
          
            # RMTSH - remote terminal
            # PROD - production level build
            # GPS - station has GPS
            #
            features = obj[FEATURES].to_s.split
            
            rsp = {
                msgtype:      ROUTER_CONFIG,
                NetID:        [@net_id],
                JoinEui:      gw.join_eui,
                region:       gw.region_code,
                hwspec:       gw.hwspec,
                freq_range:   gw.freq_range,
                DRs:          gw.drs,
                sx1301_conf:  gw.sx1301_conf,
                nocca:        gw.nocca,
                nodc:         gw.nodc,
                nodwell:      gw.nodwell
              }
            
            msg = JSON.to_json(rsp)
            
            ev.socket.message(msg)
                
          when DNTXED, PROPDF
          
            log_debug{msg}
          
          when REJOIN
          
            log_debug{msg}
          
          when JREQ
          
            # for reasons unknown LNS protocol decomposes the frame,
            # but we need it together in order to validate the MIC
            bytes = OutputCodec.new.
              put_u8(obj[MHDR]).
              put_eui(Identifier.parse(obj[JOIN_EUI]).bytes).
              put_eui(Identifier.parse(obj[DEV_EUI]).bytes).
              put_u16(obj[DEV_NONCE]).
              put_u32(obj[MIC]).
                output
              
            # this is reentrant
            frame = @decoder.decode(bytes)
            
            upinfo = obj[UPINFO]
          
            sf, bw = gw.region::RATE_TO_SF_BW[obj[DR]]
          
            yield(
              GatewayUpEvent.new(
                gw_id: gw_id,
                rx_time: ev.rx_time,
                frame: frame,
                data: bytes,
                freq: obj[FREQ],
                sf: sf, 
                bw: bw,
                rssi: upinfo[RSSI],  
                snr: upinfo[SNR],    
                gw_channels: gw.rx_channels,      
                gw_param: {
                  rctx: upinfo[RCTX],
                  xtime: upinfo[XTIME],
                  gpstime: upinfo[GPSTIME]
                }
              )
            )
          
          when UPDF
            
            payload = obj[FPORT] >= 0 ? [obj[FPORT], obj[FRM_PAYLOAD]].pack("CH*") : ""
            
            # For reasons unknown LNS protocol decomposes the frame,
            # but we need it together in order to validate the MIC.
            # Also they don't decompose it completely, we still have to 
            # interpret FCTRL.
            bytes = OutputCodec.new.
              put_u8(obj[MHDR]).
              put_u32(obj[DEV_ADDR]).
              put_u8(obj[FCTRL]).
              put_u16(obj[FCNT]).
              put_bytes([obj[FOPTS]].pack("H*")).
              put_bytes(payload).
              put_u32(obj[MIC]).
                output
            
            frame = @decoder.decode(bytes)

            if frame.nil?
              log_debug{"invalid frame"}
              return
            end

            upinfo = obj[UPINFO]

            sf, bw = gw.region::RATE_TO_SF_BW[obj[DR]]

            yield(
              GatewayUpEvent.new(
                gw_id: gw_id,
                rx_time: ev.rx_time,
                frame: frame,
                data: bytes,
                freq: obj[FREQ],
                sf: sf, 
                bw: bw,
                rssi: upinfo[RSSI],  
                snr: upinfo[SNR],           
                gw_channels: gw.rx_channels,                
                gw_param: {
                  rctx: upinfo[RCTX],
                  xtime: upinfo[XTIME],
                  gpstime: upinfo[GPSTIME]
                }
              )
            )
          
          else
          
            log_debug{"unknown message: #{obj[MSGTYPE]}"}
            
          end
          
        when LNSRouterClose
          
          gw_id = ev.socket.name
          
          @redis.del(rk_gw_status(gw_id))
        
        else
        
          log_error{"unhandled event #{ev.class}"}
          
        end
        
      end
      
    end
    
    def send_downstream(event)    
    
      socket = @server.lookup_socket(event.gw_id)
    
      log_debug{"cannot send down, socket for #{event.gw_id} does not exist"} unless socket    
      return unless socket
    
      msg = JSON.to_json(
        {
          msgtype: DNMSG,
          dC: 0,
          diid: next_token,
          pdu: event.data.bytes.map{|b|"%02X"%b}.join,
          DevEui: event.dev_eui.bytes.map{|b|"%02X"%b}.join("-"),
          RxDelay: event.rx_delay,
          RX1DR: event.rx_param.rx1.rate,
          RX1Freq: event.rx_param.rx1.freq,
          RX2DR: event.rx_param.rx2.rate,
          RX2Freq: event.rx_param.rx2.freq,
          priority: 0,
          xtime: event.gw_param[:xtime],
          rctx: event.gw_param[:rctx]      
        }
      )
      
      socket.message(msg)
      
      self
      
    end
    
    def start
      if not running?
        
        # fixme: depth
        @queue = TimeoutQueue.new(max: 100)
        
        @worker = Array.new(@num_workers) do
          Thread.new do
            
            begin
            
              loop do
            
                ev = @queue.pop
            
                begin
                  @app.call(ev)
                rescue Interrupt
                  raise
                rescue => ex
                  log_error { "caught: #{ex}:#{ex.backtrace.join("\n")}" }
                end
            
              end
                
            rescue ClosedQueueError
              log_info { "worker shutdown gracefully" }
            end
            
          end
        end
        
        @server.start
        
      end
      self
    end
    
    def stop
      if running?
        @server.stop    
        @queue.close
        @worker.each(&:join)
        @worker.clear
      end
      self
    end
    
    def running?
      @server.running?
    end
    
    def next_token
      value = @token
      @token += 1
      value
    end


  end

end
