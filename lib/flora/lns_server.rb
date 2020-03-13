require 'nio'
require 'websocket/driver'

module Flora

  class LNSServer
  
    include LoggerMethods
  
    attr_reader :selector, :server, :handler, :monitor
    
    def port
      server.addr[1] if server
    end
    
    def lookup_socket(gw_id)
      @connections.detect{|conn|conn.name == gw_id}
    end
      
    def initialize(**opts, &handler)
      
      @host = opts[:host]||'localhost'
      @port = opts[:port]||0
      
      @logger = opts[:logger]||NULL_LOGGER
      
      @selector = NIO::Selector.new      
      
      @reactor = nil
      @monitor = nil
      @server = nil
      
      @connections = []
      
      @running = false
      
      @handler = handler
      
    end
    
    def close_connection(conn)
      selector.deregister(conn.socket)
      conn.socket.close
    end
    
    def handle    
      if monitor.readable?
        @connections << LNSSocket.new(self, monitor.io.accept_nonblock, logger: @logger, &handler)        
      end    
      self
    end
    
    def running?
      @running
    end
    
    def start
      if not running?
      
        @server = TCPServer.new(@host, @port)
      
        @monitor = selector.register(server, :r)      
        @monitor.value = self
      
        @reactor = Thread.new do 
          begin
            loop do
              selector.select(1) do |m|
                m.value.handle if m.value
              end            
            end                    
          rescue Interrupt
            #exit thread
          end
        end
        
        @running = true
        
      end    
      self      
    end
    
    def stop
      if running?
        @reactor.raise Interrupt
        @reactor.join
        @connections.each do |conn|
          conn.close
        end        
        @running = false
      end
      self
    end
    
  end

end
