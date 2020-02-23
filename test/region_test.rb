require 'minitest/autorun'
require 'flora'
require 'securerandom'

describe "Region" do

  describe "EU_863_870" do
  
    Flora::EU_863_870.new("test")
    
    Flora::ChannelPlan.plan('default_eu')
  
  end


end
