require 'minitest/autorun'
require 'flora'
require 'securerandom'
require 'json'
require 'base64'
require 'logger'

describe "Semtech::Parser" do

  let(:valid_lorawan_frames) do
    [
      "\x40\x33\x22\x11\x00\x00\x00\x01\x77\x66\x55\x44"  # valid unconfirmed data up    
    ]    
  end

  let(:parser){ Flora::Semtech::Parser.new() }

  let(:yields) do
    result = []
    parser.decode(input) do |output|      
      result << output      
    end      
    result    
  end

  let(:block_called?) do      
    not yields.empty?
  end
  
  describe "#decode less than 12 bytes" do
  
    let(:input){ SecureRandom.bytes(rand(0..11)) }
  
    it "does not yield" do    
      refute block_called?    
    end
    
  end

  describe "#decode PushData without object" do
  
    let(:token){ rand(2**16)-1 }
    let(:eui){ SecureRandom.bytes(8) }
    let(:input){ [2,token,0,eui].pack("CS>Ca*") }
  
    it "does not yield" do    
      refute block_called?    
    end
  
  end

  describe "#decode PushData with empty object" do
  
    let(:token){ rand(2**16)-1 }
    let(:eui){ SecureRandom.bytes(8) }
    let(:input){ [2,token,0,eui].pack("CS>Ca*") + {}.to_json }
      
    it "yields" do
      assert block_called?
    end
    
    let(:push_ack){ yields.detect{|msg|msg.kind_of? Flora::Semtech::PushAck } }
    
    let(:other_events){ yields - [push_ack] }
    
    it "yields a PushAck with same token" do
    
      refute_nil push_ack
      assert_equal token, push_ack.token
      
    end
    
    it "doesn't yield any other events" do
      assert other_events.empty?
    end
    
  end
  
  describe "#decode PushData with n rxpk objects" do
  
    let(:payload){ valid_lorawan_frames.sample }
  
    let(:n){ rand(0..10) }
  
    let(:obj){
      {
        rxpk: Array.new(n) do
          {
            tmst: rand(0..((2**32)-1)),
            freq: 868.0,
            modu: "LORA",
            datr: "SF7BW125",
            data: Base64.strict_encode64(payload)            
          }      
        end
      }
    }
  
    let(:token){ rand(2**16)-1 }
    let(:eui){ SecureRandom.bytes(8) }
    let(:input){ [2,token,0,eui,obj].pack("CS>Ca*") + obj.to_json }
    
    let(:push_ack){ yields.detect{|msg|msg.kind_of? Flora::Semtech::PushAck } }
    
    let(:upstream_events){ yields.select{|msg|msg.kind_of? Flora::GatewayUpEvent }}
    
    let(:other_events){ yields - [push_ack, upstream_events].flatten }
    
    it "yields" do
      assert block_called?
    end
    
    it "yields a PushAck with same token" do    
      refute_nil push_ack
      assert_equal token, push_ack.token      
    end
    
    it "yields n UpstreamEvents" do
      assert_equal n, upstream_events.size
    end
    
    it "doesn't yield any other events" do
      assert other_events.empty?
    end
    
  end

  describe "#decode PullData" do
  
    let(:token){ rand(2**16)-1 }
    let(:eui){ SecureRandom.bytes(8) }
    let(:input){ [2,token,2,eui].pack("CS>Ca*") }
  
    let(:pull_ack){ yields.detect{|msg|msg.kind_of? Flora::Semtech::PullAck } }
    
    let(:pull_event){ yields.detect{|msg|msg.kind_of? Flora::GatewayPullEvent }}
  
    let(:other_events){ yields - [pull_ack, pull_event] }
  
    it "yields" do    
      assert block_called?
    end
    
    it "yields a PullAck with same token" do    
      refute_nil pull_ack
      assert_equal token, pull_ack.token      
    end
    
    it "yields a PullEvent with the same gw_id as the PullData" do
      refute_nil pull_event    
      assert_equal [eui].pack("m0"), pull_event.gw_eui
    end
    
    it "doesn't yield any other events" do
      assert other_events.empty?
    end
    
  end

end
