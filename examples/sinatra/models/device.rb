class Device < Sequel::Model  

  plugin :timestamps  
  one_to_many :lw_events

end
