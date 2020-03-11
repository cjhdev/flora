require 'openssl'

module Flora

  class SecurityModule

    include LoggerMethods

    OPTS = {}

    def initialize(keys, opts=OPTS)
      @logger = opts[:logger]||NULL_LOGGER
      @keys = keys
    end
    
    def mic(key, *data)
    
      raise RangeError.new "unknown key" unless @keys[key]
      
      kek = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      kek.padding = 0
      kek.key = @keys[key].unpack("m").first
      
      k = kek.update("\x00" * 16).bytes
      
      k1k2 = Array.new(2).map do
        k = k.pack("C*").unpack('B*').first
        msb = k.slice!(0)
        k = [k, '0'].pack('B*').bytes
        k[15] ^= 0x87 if msb == '1'
        k.dup
      end
      
      cipher = OpenSSL::Cipher.new("AES-128-CBC").encrypt
      cipher.key = @keys[key].unpack("m").first
      cipher.iv = ("\x00" * 16)
      
      buffer = data.join
      
      while buffer.size > 16 do
      
        cipher.update(buffer.slice!(0...16))
        
      end
      
      block = buffer.bytes
      buffer.clear
      
      k = k1k2[block.size == 16 ? 0 : 1].dup
      
      i = block.size.times { |ii| k[ii] ^= block[ii] }
      
      if i < 16
      
        k[i] ^= 0x80 if i < 16
        
      end
      
      mac = cipher.update(k.pack('C*')) + cipher.final
      
      mac.unpack("L<").first
      
    end
    
    def ctr(key, iv, data)
    
      return data if data.empty?
      raise RangeError.new "unknown key '#{key}'" unless @keys[key]
      
      cipher = OpenSSL::Cipher.new("AES-128-CTR").encrypt
      cipher.padding =  0
      cipher.key = @keys[key].unpack("m").first
      cipher.iv = iv
      
      cipher.update(data) + cipher.final
      
    end
    
    def ecb_encrypt(key, data)
      
      raise RangeError.new "unknown key" unless @keys[key]
      
      cipher = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      cipher.padding = 0
      cipher.key = @keys[key].unpack("m").first
      
      cipher.update(data)
      
    end
    
    def ecb_decrypt(key, data)
      
      raise RangeError.new "unknown key" unless @keys[key]
      raise ArgumentError unless (data.size % 16) == 0
      
      cipher = OpenSSL::Cipher.new("AES-128-ECB").decrypt
      cipher.padding = 0
      cipher.key = @keys[key].unpack("m").first
      
      cipher.update(data)
      
    end
    
    # LoRaWAN 1.0 derivation
    def derive_keys(join_nonce, net_id, dev_nonce)
    
      nwk = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      nwk.key = @keys[:nwk].unpack("m").first
    
      iv = OutputCodec.new.put_u24(join_nonce).put_u24(net_id).put_u16(dev_nonce).put_bytes("\x00\x00\x00\x00\x00\x00\x00").output
      
      @keys[:apps] = [nwk.update("\x02".concat(iv))].pack("m0")
      @keys[:fnwksint] = [nwk.update("\x01".concat(iv))].pack("m0")
        
      @keys[:snwksint] = @keys[:fnwksint]
      @keys[:nwksenc] = @keys[:fnwksint]
      @keys[:jsenc] = @keys[:fnwksint]
      @keys[:jsint] = @keys[:fnwksint]
        
    end
    
    # LoRaWAN 1.1 derivation
    def derive_keys2(join_nonce, join_eui, dev_nonce, dev_eui)
      
      iv = OutputCodec.new.put_u24(join_nonce).put_eui(join_eui).put_u16(dev_nonce).put_u16(0).output      
      join_iv = OutputCodec.new.put_eui(dev_eui).put_bytes("\x00" * 7).output
      
      nwk = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      nwk.key = @keys[:nwk].unpack("m").first
    
      @keys[:jsenc] =    [nwk.update("\x05".concat(join_iv))].pack("m0")
      @keys[:jsint] =    [nwk.update("\x06".concat(join_iv))].pack("m0")
      @keys[:fnwksint] = [nwk.update("\x01".concat(iv))].pack("m0")
      @keys[:snwksint] = [nwk.update("\x03".concat(iv))].pack("m0")      
      @keys[:nwksenc] =  [nwk.update("\x04".concat(iv))].pack("m0")
      
      if @keys[:app]
      
        app = OpenSSL::Cipher.new("AES-128-ECB").encrypt
        app.key = @keys[:app].unpack("m").first
        
        @keys[:apps] = [app.update("\x02".concat(iv))].pack("m0")
        
      end
      
    end
    
    def init_a(dev_addr, upstream, counter)
      
      out = OutputCodec.new(logger: @logger)
      
      out.put_u8(1)
      out.put_u32(0)
      out.put_u8(upstream ? 0 : 1)
      out.put_u32(dev_addr)
      out.put_u32(counter)
      out.put_u16(0)
      
      out.output
      
    end
    
    def init_b(confirm_counter, rate, ch_index, upstream, dev_addr, counter, len)
    
      out = OutputCodec.new(logger: @logger)
      
      out.put_u8(0x49)
      out.put_u16(confirm_counter)
      out.put_u8(rate)
      out.put_u8(ch_index)
      out.put_u8(upstream ? 0 : 1)
      out.put_u32(dev_addr)
      out.put_u32(counter)
      out.put_u8(0)
      out.put_u8(len)
      
      out.output
    
    end
    
  end

end
