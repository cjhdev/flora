require 'minitest/autorun'
require 'flora'
require 'logger'
require 'securerandom'

describe "Defer" do

  describe "#on_timeout" do
  
    let(:defer){ Flora::Defer.new(logger: Logger.new(STDOUT)) }
  
    before do
      defer.start
    end
  
    it "fires event" do
      
      q = Queue.new
  
      defer.on_timeout 0.1 do        
        q.push nil        
      end

      Timeout::timeout 1 do
        q.pop
      end
    
    end
    
    after do
      defer.stop
    end
  
  end
  
end
