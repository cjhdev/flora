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
  let(:connector){Flora::LNSConnector.new(logger: logger, redis: redis, gw_manager: gw_manager)}
  let(:port){connector.port}
  
  let(:token1){[SecureRandom.bytes(32)].pack("m0")}
  let(:token2){[SecureRandom.bytes(32)].pack("m0")}
  
  let(:eui1){SecureRandom.bytes(8)}
  let(:eui2){SecureRandom.bytes(8)}

  before do
    connector.start          
    socket.open 
  end

  describe "info" do
    
    let(:socket){ WebSocketClient.new("wss://localhost:#{port}/router-info", token: client_token) }
    
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
        assert_equal "router-#{[server_eui].pack("m0")}", info['uri']
        
        sleep 0.1
        
        assert socket.closed?
      
      end
    
    end
    
  end
  
  describe "version" do
    
    let(:server_token){token1}
    let(:client_token){token1}
    
    let(:server_eui){eui1}
    let(:client_eui){eui1}
    
    let(:socket){ WebSocketClient.new("wss://localhost:#{port}/router-#{[server_eui].pack("m0")}", token: client_token) }
    
    before do
      gw()
      socket.tx(
        {
          msgtype: 'version'
        }        
      )          
    end
    
    it "returns router-config" do
    
      config = socket.rx(timeout: 1)
      
      assert_instance_of Hash, config
      
      assert_equal 'router_config', config['msgtype']
      
      assert_instance_of Array, config['NetID']
      refute config['NetID'].empty?
      assert config['NetID'].all?{|v|v.kind_of? Integer}
      
      assert_instance_of Array, config['JoinEUI']
      refute config['JoinEUI'].empty?
      assert config['JoinEUI'].all? do |v|
        v.kind_of? Array and v.size == 2 and v.all?{|vv|vv.kind_of? Integer}
      end
      
      assert_instance_of String, config['region']
      
      assert_instance_of String, config['hwspec']
      
      assert_instance_of Array, config['freq_range']
      assert_equal 2, config['freq_range'].size
      assert config['freq_range'].all? {|v| v.kind_of? Integer }
      
      assert_instance_of Array, config['DRs']
      assert_equal 16, config['DRs'].size
      
      # todo...
      
      sleep 0.1
      
      # socket remains open
      refute socket.closed?
    
    end
    
  end
  
  after do
    socket.close
    connector.stop
  end

end
