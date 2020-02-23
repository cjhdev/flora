module Flora

  module Conversion
  
    def bytes_to_hex(bytes)
      bytes.bytes.map{|b|"%02X"%b}.join
    end
    
    def hex_to_bytes(hex)
      [hex].pack("H*")
    end

    def symbolise(obj)
      if obj.kind_of? Array
        obj.map do |v|
          send(__method__, v)
        end
      elsif obj.kind_of? Hash
        obj.map do |k,v|
          [
            k.to_sym,
            send(__method__, v)
          ]
        end.to_h
      else
        obj
      end      
    end
    
  end

end
