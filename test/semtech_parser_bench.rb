require 'minitest/autorun'
require 'flora'
require 'logger'
require 'securerandom'
require 'minitest/benchmark'

describe "Semtech::Parser Benchmark" do

  def self.bench_range
    [1, 10, 100, 1_000]
  end

  let(:obj) do
    {
      rxpk: [
        {
          data: [frame.encode].pack("m"),
          tmst: 0,
          freq: 0,
          modu: "LORA",
          datr: "SF7BW125"
        }
      ]
    }
  end
  
  let(:msg) do    
    Flora::Semtech::PushData.new(0, gw_eui, obj).encode
  end
  
  #let(:parser){ Flora::Semtech::Parser.new(logger: Logger.new(STDOUT)) }
  let(:parser){ Flora::Semtech::Parser.new(logger: Logger.new(STDOUT)) }

  describe "data_unconfirmed_up" do
    
    let(:dev_addr){0}
    let(:adr){false}
    let(:adr_ack_req){false}
    let(:ack){false}
    let(:pending){false}
    let(:counter){0}
    let(:opts){""}
    let(:port){nil}
    let(:data){nil}
    let(:mic){0}
    
    let(:frame){ Flora::DataUnconfirmedUp.new(dev_addr, adr, adr_ack_req, ack, pending, counter, opts, port, data, mic) }
    
    let(:gw_eui){SecureRandom.bytes(8)}
    
    bench_performance_linear "Semtech::Parser",  0.999 do |n|
      
      n.times do
    
        parser.decode(msg) do |ev|
          #puts ev
        end
    
      end
      
    end

  end


end
