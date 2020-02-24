require 'minitest/autorun'
require 'flora'
require 'logger'
require 'securerandom'
require 'fakeredis'

describe "DeviceManager" do

  let(:defer){ Flora::DeferQueue.new }
  let(:logger){ Logger.new(STDOUT) } 
  let(:redis){ Redis.new } 
  let(:dev_eui){SecureRandom.bytes(8)}
  let(:nwk_key){SecureRandom.bytes(16)}
  let(:dev_addr){rand(0..2**24-1)}
  let(:dm){ Flora::DeviceManager.new(redis: redis, logger: logger, defer: defer) }
  
  describe "#new_device" do
  
    let(:device) do      
      dm.create_device(dev_eui: dev_eui, nwk_key: nwk_key, dev_addr: dev_addr)      
    end
  
    it "returns device instace" do    
      assert_instance_of Flora::Device, device
    end
    
    it "stores in redis" do
      refute_nil redis.get(dm.rk_eui(device.name))    
    end
    
  end

  describe "#lookup_by_addr" do
  
    describe "no match" do
    
      it "returns nil" do      
        assert_nil dm.lookup_by_addr(42)
      end
    
    end
    
    describe "match" do
    
      let(:first){dm.create_device(dev_eui: dev_eui, nwk_key: nwk_key, dev_addr: dev_addr)}
    
      it "returns a match" do      
        refute_nil dm.lookup_by_addr(first.dev_addr)
      end
    
    end
    
  end

  describe "#lookup_by_eui" do
  
    describe "no match" do
    
      it "returns nil" do      
        assert_nil dm.lookup_by_eui(dev_eui)
      end
    
    end
    
    describe "match" do
    
      before do
        dm.create_device(dev_eui: dev_eui, nwk_key: nwk_key, dev_addr: dev_addr)
      end
    
      it "returns a match" do      
        refute_nil dm.lookup_by_eui(dev_eui)
      end
    
    end
  
  end
  
  describe "#export_device" do
  
    let(:device) do      
      dm.create_device(dev_eui: dev_eui, nwk_key: nwk_key, dev_addr: dev_addr)      
    end
    
    let(:exported) do
      dm.export_device(device.dev_eui)
    end
    
    it "produces export format" do    
      
      assert_kind_of Hash, exported
      
      assert_kind_of Integer, exported["version"]
      assert_kind_of Hash, exported["fields"]
      assert_kind_of Time, exported["exported_at"]
      
    end
  
  end
  
  describe "#restore_device" do
  
    let(:device) do      
      dm.create_device(dev_eui: dev_eui, nwk_key: nwk_key, dev_addr: dev_addr)      
    end
    
    let(:exported) do
      dm.export_device(device.dev_eui)
    end
    
    it "accepts exported record" do        
      dm.restore_device(exported)      
    end
    
    describe "unjoined device" do
      
      
      
    end
  
    describe "joined device" do
    
      
    
    end
  
  end
  
end
