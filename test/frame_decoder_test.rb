require 'minitest/autorun'
require 'flora'

describe "FrameDecoder" do

  describe "#decode" do
      
    let(:output){ Flora::FrameDecoder.new.decode(input) }
      
    describe "empty input" do
      
      let(:input){""}
      
      it "returns nil" do      
        assert_nil output      
      end
    
    end
    
    describe "join request" do
    
      let(:input) { "\x00\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xbb\xbb\xbb\xbb\xbb\xbb\xbb\xbb\x00\x00\xff\xff\xff\xff" }      
      
      it "returns expected class instance" do
        assert_instance_of Flora::JoinRequest, output
      end
      
    end
    
    describe "join request too short" do
    
      let(:input) { "\x00\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xbb\xbb\xbb\xbb\xbb\xbb\xbb\xbb\x00\x00\xff\xff\xff" }      
      
      it "returns nil" do
        assert_nil output
      end
      
    end
    
    describe "rejoin request" do
    
      let(:input) { "\xC0\x00\xbb\xbb\xbb\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\x00\x00\xff\xff\xff\xff" }      
        
      it "returns expected class instance" do
        assert_instance_of Flora::RejoinRequest, output
      end
      
    end
    
    describe "rejoin request too short" do
    
      let(:input) { "\xC0\x00\xbb\xbb\xbb\xaa\xaa\xaa\xaa\xaa\xaa\xaa\xaa\x00\x00\xff\xff\xff" }      
        
      it "returns nil" do
        assert_nil output
      end
      
    end
    
    describe "data unconfirmed up" do
    
      let(:input) { "\x40\x33\x22\x11\x00\x00\x00\x01\x77\x66\x55\x44" }      
      
      it "returns expected class instance" do
        assert_instance_of Flora::DataUnconfirmedUp, output
      end
    
    end
    
    describe "data unconfirmed up too short" do
    
      let(:input) { "\x40\x33\x22\x11\x00\x00\x00\x01\x77\x66\x55" }      
      
      it "returns nil" do
        assert_nil output
      end
    
    end
    
    describe "data confirmed up" do
    
      let(:input) { "\x80\x33\x22\x11\x00\x00\x00\x01\x77\x66\x55\x44" }      
      
      it "returns expected class instance" do
        assert_instance_of Flora::DataConfirmedUp, output
      end
    
    end
    

  end

end
