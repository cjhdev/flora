require 'minitest/autorun'
require 'flora'
require 'logger'
require 'securerandom'
require 'minitest/benchmark'

describe "Device Benchmark" do

  before do
    defer.start
  end

  let(:defer){ Flora::DeferQueue.new(logger: logger) }
  let(:logger){ Logger.new(STDOUT) }
  let(:redis){Redis.new}
  let(:dev_nonce){ 0 }
  let(:dev_eui){SecureRandom.bytes(8)}
  let(:join_eui){SecureRandom.bytes(8)}
  let(:nwk_key){SecureRandom.bytes(16)}
  let(:gw_eui){ "agateway" }
  let(:dev_addr){rand(0..2**24-1)}
  let(:device){ Flora::DeviceManager.new(redis: redis, logger: logger, defer: defer).create_device(dev_eui: dev_eui, nwk_key: nwk_key, dev_addr: dev_addr) }

  let(:event) do
    Flora::GatewayUpEvent.new(
      rx_time: Time.now,
      freq: Flora::EU_863_870::CHANNELS.first.freq,
      sf: 12,
      bw: 125000,
      data: frame.encode,
      frame: frame,
      id: gw_eui,
      gw_param: {tmst: Time.now.to_i},
    )      
  end

  describe "JoinRequest" do
    
    def mic_join_request(data)
      device.sm.mic(:nwk, data.slice(0..-5))
    end
    
    let(:frame) do
      f = Flora::JoinRequest.new(
        join_eui,
        device.dev_eui,
        dev_nonce,
        0
      )
      f.mic = mic_join_request(f.encode)    
      f
    end
    
    def self.bench_range
      [1, 10, 100, 1_000]
    end
    
    bench_performance_linear "Device#process_join_request",  0.999 do |n|
      
      event
      
      n.times do
      
        device.clear_join_counter!
        device.record[:dev_nonce] = nil
        device.process_join_request(event)
    
      end
      
    end
    
  
  end
  
end
