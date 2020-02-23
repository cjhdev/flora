module Flora

  class InputCodec
  
    U8  = "C".freeze
    U16 = "S<".freeze
    U24 = "CCC".freeze
    U32 = "L<".freeze
  
    def initialize(input)
      @input = input
      @s = input.dup      
    end
    
    def remaining
      @s.size
    end
  
    def get_u8
      @s.slice!(0).unpack(U8).first unless @s.empty?
    end
  
    def get_u16
       @s.slice!(0,2).unpack(U16).first unless @s.size < 2
    end
  
    def get_u24
      @s.slice!(0,3).unpack(U24).inject(0) do |r, v|      
        r = r << 8
        r |= v              
      end unless @s.size < 3
    end
  
    def get_u32
      @s.slice!(0,4).unpack(U32).first unless @s.size < 4
    end
  
    def get_eui
      @s.slice!(0,8).reverse! unless @s.size < 8
    end
    
    def get_bytes(n)
      @s.slice!(0,n) unless @s.size < n
    end
    
    def eof?
      @s.size == 0
    end
    
  end
  
  class OutputCodec
  
    U8  = "C".freeze
    U16 = "S<".freeze
    U24 = "CCC".freeze
    U32 = "L<".freeze
    
    attr_reader :output
    
    def initialize(output="", **opts) 
      raise TypeError unless output.kind_of? String
      @output = output
    end
    
    def put_u8(input)
      @output.concat [input].pack(U8)
      self
    end
  
    def put_u16(input)
      @output.concat [input].pack(U16)
      self
    end
  
    def put_u24(input)    
      @output.concat [input, input >> 8, input >> 16].pack(U24)
      self
    end
  
    def put_u32(input)
      @output.concat [input].pack(U32)
      self
    end
  
    def put_eui(input)
      @output.concat input.reverse
      self      
    end
    
    def put_bytes(input)
      @output.concat input
      self
    end
    
  end

end
