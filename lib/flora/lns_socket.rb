require 'nio'
require 'websocket/driver'

module Flora
  
  LNSInfoConnect = Struct.new(:rx_time, :socket, keyword_init: true)
  LNSInfoMessage = Struct.new(:rx_time, :msg, :socket, keyword_init: true)
  
  GatewayConnectEvent = Struct.new(:rx_time, :socket, keyword_init: true)  
  GatewayMessageEvent = Struct.new(:rx_time, :msg, :socket, keyword_init: true)
  
  class LNSSocket
    
    include LoggerMethods
    
    attr_reader :monitor, :driver, :server, :socket, :name, :auth_token
    
    PATH_INFO = "PATH_INFO"
    PATH_PATTERN = Regexp.new("^/router-(?<name>[0-9a-zA-Z+/=]+)$")
    INFO = "info"
    HTTP_AUTHORIZATION = "HTTP_AUTHORIZATION"
    
    def url
      driver.url
    end
    
    def initialize(server, socket, **opts)
      
      @logger = opts[:logger]||NULL_LOGGER
      
      @socket = socket
      @server = server
      @token = 0
      @driver = WebSocket::Driver.server(self)
      @monitor = server.selector.register(socket, :r)      
      @monitor.value = self
      @mutex = Mutex.new
      @name = nil
      
      driver.on :connect, -> (ev) do
        
        if not WebSocket::Driver.websocket?(driver.env) 
          close_socket()
          return
        end
        
        match = PATH_PATTERN.match(driver.env[PATH_INFO])
        
        if match.nil?
          close_socket()
          return
        end
        
        # resource name
        @name = match[:name]
        
        @auth_token = driver.env[HTTP_AUTHORIZATION]
        
        if name == INFO
        
          log_info{"info connect"}
          
          driver.start
      
        else
      
          yield(
            GatewayConnectEvent.new(
              socket: self,
              rx_time: Time.now
            )
          )
        
        end
          
      end
      
      driver.on :message, -> (ev) do
      
        # there is no reason to send a message this large so assume
        # tamper
        if ev.data.size > 1024
          close()
          return 
        end
          
        if @name == INFO

          yield(
            LNSInfoMessage.new(
              socket: self,
              msg: ev.data,
              rx_time: Time.now 
            )
          )

        else

          yield(
            GatewayMessageEvent.new(
              socket: self,
              msg: ev.data,
              rx_time: Time.now 
            )
          )
          
        end
        
      end
      
      driver.on :close do |ev|
        close_socket()
      end
      
    end
    
    # called by the reactor thread
    def handle    
      begin
        data = socket.read_nonblock(500)
        with_mutex do 
          driver.parse(data)
        end
      rescue IO::WaitReadable
      rescue EOFError, IOError => e
        log_debug { "#{e}" }
        close()
      rescue => e
        log_error { "#{e}: #{e.backtrace.join("\n")}" }
        close()
      end
    end

    # called by driver
    def write(data)      
      @socket.write(data)
      @socket.flush
      self
    end
    
    # called by worker
    def start_websocket
      with_mutex do
        driver.start
      end      
    end

    # called by worker
    def message(msg)
      with_mutex do
        driver.text(msg)        
      end
    end
    
    # called by worker
    def message_and_close(msg)
      with_mutex do
        driver.text(msg)
        close_socket unless driver.close
      end
    end
    
    # called by worker and reactor
    def close
      with_mutex do
        close_socket unless driver.close        
      end
    end
    
    private
    
      def next_token
        value = @token
        @token += 1
        value
      end
      
      def with_mutex
        @mutex.synchronize do
          yield
        end
      end
      
      # close TCP socket and deregister monitor
      def close_socket
        server.close_connection(self)
      end
     
  end

end
