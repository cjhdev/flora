class LwEvent < Sequel::Model  

  plugin :timestamps  
  plugin :class_table_inheritance, key: :type
  
  many_to_one :device
  one_to_many :lw_gateway_metas
  
end
