require 'websocket/driver'
require 'socket'
require 'uri'
require 'json'

class WebSocketClient

  attr_reader :driver, :socket

  def closed?
    @closed
  end

  def initialize(uri, **opts)
  
    @uri = URI.parse(uri)    
    @closed = true
    @worker = nil
    @reads = Flora::TimeoutQueue.new
    @mutex = Mutex.new
    @token = opts[:token]
  
  end
  
  # written by driver
  def write(data)    
    @socket.write(data)
    @socket.flush
  end
  
  # required by driver
  def url
    @uri.to_s
  end  
  
  def open
    
    if @closed
    
      @socket = TCPSocket.new(@uri.host, @uri.port)
      
      @driver = WebSocket::Driver.client(self)
      
      @driver.set_header("Authorization", @token.to_s) if @token
      
      driver.on :close do |ev|
        
        @socket.close
        @closed = true
        
      end
      
      driver.on :connect do 
      end
      
      driver.on :message do |ev|
        
        begin
          obj = JSON.parse(ev.data)
          @reads.push(obj)
        rescue
        end
        
      end
      
      @closed = false
      
      @worker = Thread.new do
        
        begin
        
          loop do
          
            @socket.wait_readable
            
            data = @socket.read(@socket.nread)
            
            with_mutex do
              driver.parse(data)
            end
            
          end
          
        rescue IOError          
        end
      
      end
      
      driver.start
      
    end
    
    self
    
  end
  
  def close
    with_mutex do
      socket.close unless driver.close
    end
  end
  
  def tx(obj)
    with_mutex do
      driver.text(obj.to_json)
    end
  end
  
  def rx(**opts)
    begin
      @reads.pop(timeout: opts[:timeout])
    rescue ThreadError
      raise ThreadError.new "timeout"
    end
  end
  
  def with_mutex
    @mutex.synchronize do
      yield
    end
  end  
  
end
