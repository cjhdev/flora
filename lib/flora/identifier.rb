module Flora

  class Identifier
  
    NIBBLE = "[0-9a-fA-F]"
    OCTET = "(#{NIBBLE}#{NIBBLE})"
    
    DELIM1 = Regexp.new(Array.new(8){OCTET}.join("-"))
    
    ZERO = "\x00" * 8
    
    def bytes
      @value
    end
    
    def self.parse(input)
    
      if input.kind_of? Integer
        from_int(input)
      elsif input.kind_of? String
        from_eui(input) || from_id6(input)
      else
        nil
      end
    
    end
    
    def self.from_eui(input)
    
      if value = DELIM1.match(input)
        
        self.new(
          [value.captures.join].pack("H16")
        )
      end
    end
    
    def self.from_id6(input)
      begin
        self.new(
          IPAddr.new(input).hton.slice(0,8)      
        )
      rescue
        nil
      end
    end
    
    def self.from_int(input)
      if (0..2**64-1).include? input
        self.new([input].pack("Q>"))
      end
    end
    
    def initialize(bytes)
      @value = bytes
    end
    
    def to_eui
      @value.bytes.map{|b|"%02X"%b}.join("-")
    end
    
    def to_id6    
      IPAddr.new_ntoh(ZERO + @value).to_s    
    end
    
    def to_i
      @value.unpack("Q>").first
    end
    
    def to_b64
      [@value].pack("m0")
    end
    
  end

end
