require 'minitest/autorun'
require 'minitest/benchmark'
require 'flora'
require 'logger'
require 'securerandom'

describe "Device" do

  before do
    defer.start
  end

  def mic_join_request(data)
    device.sm.mic(:nwk, data.slice(0..-5))
  end
  
  let(:gw_eui){ "agateway" }
  let(:defer){ Flora::DeferQueue.new(logger: logger) }
  let(:logger){Logger.new(STDOUT)}
  let(:redis){Redis.new}
  let(:dev_eui){SecureRandom.bytes(8)}
  let(:join_eui){SecureRandom.bytes(8)}
  let(:nwk_key){SecureRandom.bytes(16)}
  let(:dev_addr){rand(0..2**24-1)}
  let(:device){ Flora::DeviceManager.new(redis: redis, logger: logger, defer: defer).create_device(dev_eui: dev_eui, nwk_key: nwk_key, dev_addr: dev_addr) }
  let(:dev_nonce){ 0 }  
  let(:freq){ Flora::EU_863_870::CHANNELS.first.freq }
  
  let(:join_frame) do
    f = Flora::JoinRequest.new(
      join_eui,
      device.dev_eui,
      dev_nonce,
      0
    )
    f.mic = mic_join_request(f.encode)    
    f
  end
  
  let(:join_event) do
    Flora::GatewayUpEvent.new(
      rx_time: Time.now,
      tmst: Time.now.to_i, 
      freq: Flora::EU_863_870::CHANNELS.first.freq,
      sf: 12,
      bw: 125000,
      data: join_frame.encode,
      frame: join_frame,
      rssi: -50,
      snr: 9,
      gw_eui: gw_eui
    )      
  end
  
  describe "process_join_request" do
    
    it "returns self to indicate frame accepted" do
      assert_equal device, device.process_join_request(join_event)
    end
    
    it "yields downstream and activation event" do
    
      result = []
      
      device.process_join_request(join_event) do |output|      
        result << output              
      end   
    
      sleep 1
    
      assert_instance_of Flora::GatewayDownEvent, result[0]
      assert_instance_of Flora::ActivationEvent, result[1]
      assert_instance_of Flora::DeviceUpdateEvent, result[2]
    
    end
    
  end
  
  describe "process unconfirmed_data" do

    let(:up_count){ 0 }
  
    let(:data_frame) do
      f = Flora::DataUnconfirmedUp.new(
        device.dev_addr,
        false,
        false,
        false,
        false,
        up_count,
        "",
        nil,
        nil,
        0
      )
      f.mic = device.mic_data_up(up_count, f.encode, 0, 0, freq) 
      f
    end
    
    let(:data_event) do
      Flora::GatewayUpEvent.new(
        rx_time: Time.now,
        tmst: Time.now.to_i, 
        freq: freq,
        sf: 12,
        bw: 125000,
        data: data_frame.encode,
        frame: data_frame,
        rssi: -50,
        snr: 9,
        gw_eui: gw_eui
      )      
    end
    
    before do
      device.process_join_request(join_event)
      device.record[:join_time] = (Time.now - 10).to_f
    end
    
    it "returns self to indicate frame accepted" do
      
      skip "won't work until add support for avoiding time locks"
      
      # this won't work, need device manager support for inserting old(er) records
      assert_equal device, device.process_data_up(data_event)
    end
      
  end

end
