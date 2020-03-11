require_relative "websocket_client"

require 'minitest/autorun'
require 'flora'
require 'logger'
require 'securerandom'
require 'fakeredis'

describe "LNSConnector" do

  let(:redis){Redis.new}  
  let(:gw){gw_manager.create_gateway(eui: server_eui, config: 'sx1301_eu868_1', token: server_token)}
  let(:gw_manager){Flora::GatewayManager.new(logger: logger, redis: redis)}
  let(:logger){Logger.new(STDOUT)}
  let(:socket){ WebSocketClient.new("wss://localhost:#{port}/router-info", token: client_token) }
  let(:connector){Flora::LNSConnector.new(logger: logger, redis: redis, gw_manager: gw_manager)}
  let(:port){connector.port}
  
  let(:token1){[SecureRandom.bytes(32)].pack("m0")}
  let(:token2){[SecureRandom.bytes(32)].pack("m0")}
  
  let(:eui1){SecureRandom.bytes(8)}
  let(:eui2){SecureRandom.bytes(8)}

  before do
    connector.start          
  end

  describe "discovery" do
    
    before do        
      socket.open         
    end
       
    describe "bad token" do
    
      let(:server_token){token1}
      let(:client_token){token2}
      
      let(:server_eui){eui1}
      let(:client_eui){eui1}
      
      before do
        gw()
        socket.tx({router: client_eui.bytes.map{|b|"%02X"%b}.join("-")})          
      end
      
      it "returns info without uri and closes socket" do
      
        info = socket.rx(timeout: 1)
        
        assert_instance_of Hash, info
        
        #assert_equal client_eui, Flora::Identifier.from_id6(info['router']).bytes
        assert_instance_of String, info['error']        
        assert_nil info['uri']
        
        sleep 0.1
        
        assert socket.closed?
      
      end
      
    end 
    
    describe "valid token, bad eui" do
    
      let(:server_token){token1}
      let(:client_token){token1}
      
      let(:server_eui){eui1}
      let(:client_eui){eui2}
      
      before do
        gw()
        socket.tx({router: client_eui.bytes.map{|b|"%02X"%b}.join("-")})                  
      end
      
      it "returns info without uri and closes socket" do
      
        info = socket.rx(timeout: 1)
        
        assert_instance_of Hash, info
        
        #assert_equal client_eui, Flora::Identifier.from_id6(info['router']).bytes
        assert_instance_of String, info['error']        
        assert_nil info['uri']
        
        sleep 0.1
        
        assert socket.closed?
      
      end
      
    end
    
    describe "valid token" do
    
      let(:server_token){token1}
      let(:client_token){token1}
      
      let(:server_eui){eui1}
      let(:client_eui){eui1}
      
      before do
        gw()
        socket.tx({router: client_eui.bytes.map{|b|"%02X"%b}.join("-")})                  
      end
      
      it "returns info with uri and closes socket" do
      
        info = socket.rx(timeout: 1)
        
        assert_instance_of Hash, info
        
        #assert_equal client_eui, Flora::Identifier.from_id6(info['router']).bytes
        assert_nil info['error']
        
        sleep 0.1
        
        assert socket.closed?
      
      end
    
    end
    
    after do
      socket.close
    end
  
  end
  
  after do
    connector.stop
  end

end
