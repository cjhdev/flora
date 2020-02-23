require 'minitest/autorun'
require 'flora'

describe "Gateway management" do

  let(:gw){ Flora::Gateway.new }

  it "is stopped after #initialise" do
    refute gw.running?
  end

  describe "#start" do
  
    describe "from stop" do
  
      before do
        gw.start
      end
      
      it "is running" do    
        assert gw.running?      
      end
    
      after do
        gw.stop
      end
      
    end
    
  end
    
  describe "#stop" do
  
    describe "when started" do
  
      before do      
        gw.start
        gw.stop      
      end
      
      it "is not running" do
        refute gw.running?
      end
      
    end
    
    describe "when stopped" do
    
      before do      
        gw.stop      
      end
      
      it "is not running" do
        refute gw.running?
      end
    
    end
  
  end

  describe "#restart" do
      
    describe "when started" do
    
      before do
        gw.start
        gw.restart
      end
      
      it "is running" do
        assert gw.running?
      end
      
      after do
        gw.stop
      end
      
    end
    
    describe "when stopped" do
    
      before do
        gw.restart
      end
      
      it "is running" do
        assert gw.running?
      end
      
      after do
        gw.stop
      end
    
    end
  
  end
    
  describe "#port" do
  
    describe "when started" do
  
      before do
        gw.start
      end
      
      it "returns the listen port" do
        assert_kind_of Integer, gw.port
      end
      
    end
    
    describe "when stopped" do
    
      it "returns the listen port" do
        assert_nil gw.port
      end
    
    end
  
  end
  
  describe "#send_msg" do
  
    describe "when started" do    
    end
    
    describe "when stopped" do
    
      it "raises an exception" do
        assert_raises Exception do 
          gw.send_msg("hello", [])
        end
      end
    
    end
    
  end
    
end
