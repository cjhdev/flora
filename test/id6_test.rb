require 'minitest/autorun'
require 'flora'

describe "ID6" do

  describe "full" do
  
    let(:input){"1:100:1:100"}
    let(:expected){"\x00\x01\x01\x00\x00\x01\x01\x00"}
  
    it "parses" do    
      assert_equal expected, Flora::ID6.decode(input).value    
    end
    
    it "encodes" do
      assert_equal input, Flora::ID6.decode(input).to_s
    end
    
  end

  describe "empty" do
  
    let(:input){""}
    
    it "parses" do    
      assert_nil Flora::ID6.decode(input)
    end
    
  end

  describe "first" do
  
    let(:input){"::1:100"}
    let(:expected){"\x00\x00\x00\x00\x00\x01\x01\x00"}
  
    it "parses" do    
      assert_equal expected, Flora::ID6.decode(input).value    
    end
    
    it "encodes" do
      assert_equal input, Flora::ID6.decode(input).to_s
    end
    
  end

  describe "mid" do
  
    let(:input){"1::100"}
    let(:expected){"\x00\x01\x00\x00\x00\x00\x01\x00"}
  
    it "parses" do    
      assert_equal expected, Flora::ID6.decode(input).value    
    end
    
    it "encodes" do
      assert_equal input, Flora::ID6.decode(input).to_s
    end
    
  end
  
  describe "last" do
  
    let(:input){"1:100::"}
    let(:expected){"\x00\x01\x01\x00\x00\x00\x00\x00"}
  
    it "parses" do    
      assert_equal expected, Flora::ID6.decode(input).value    
    end
    
    it "encodes" do
      assert_equal input, Flora::ID6.decode(input).to_s
    end
    
  end
  
  
  
end
