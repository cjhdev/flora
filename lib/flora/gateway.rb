require 'socket'

module Flora

  class Gateway

    include LoggerMethods
    include RedisKeys

    def next_token
      value = @token
      @token += 1
      value
    end

    def initialize(**opts)
    
      @host = opts[:host]||'localhost'
      @port = opts[:port]||0
      @logger = opts[:logger]
      @num_workers = opts[:num_gw_workers]||1
      @redis = opts[:redis]
    
      @token = rand(0..(2**16-1))
      @socket = nil
      @running = false      
      @worker = []
      @app = Proc.new do
      
        parser = Semtech::Parser.new(logger: @logger)
      
        begin
      
          loop do
            
            input, sender = @socket.recvfrom(1024, 0)

            parser.decode(input) do |event|
            
              log_debug "yielded #{event}"
            
              case event
              when GatewayUpEvent
              
                if return_addr = restore_gateway(event.gw_eui)
                
                  event.ip_addr = return_addr[:addr]
                  event.port = return_addr[:port]
              
                else
                
                  event.ip_addr = sender[3]
                  event.port = sender[1]
                  
                end
                
                yield(event)
              
              when GatewayPullEvent
              
                save_gateway(event.gw_eui, sender[3], sender[1])
              
              when Semtech::PullAck, Semtech::PushAck
              
                send_msg(event.encode, sender[3], sender[1])
                
              end
              
            end
          
          end
         
        # socket was closed
        rescue IOError
        # something else
        rescue => e
          log_debug "caught exception: #{e}: #{e.backtrace.join('\n')}"
        end
        
        @running = false
      
      end
      
    end
        
    def send_downstream(event)
      send_msg(
        Semtech::PullResp.new(next_token, event).encode,
        event.ip_addr,
        event.port
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
    
    private :send_msg
    
  end

end
