module Flora

  class Frame
    
    @type = nil
  
    @@subs = []
    
    def self.inherited(klass)
      if self == Frame
        @@subs << klass
      else
        superclass.inherited(klass)
      end
    end
    
    def self.type
      @type
    end
    
    def type
      self.class.type
    end
    
    def self.subs
      @@subs
    end
    
    def self.tag
      (@type << 5)
    end
    
    def self.tag_to_cls(tag)
      if (tag & 0x1f) == 0
        @@subs.detect{|cls|cls.type == (tag >> 5)}
      else
        nil
      end
    end
    
    attr_accessor :mic
  
  end
  
  class JoinRequest < Frame
    
    @type = 0
    
    def self.decode(s)
    
      join_eui = s.get_eui
      dev_eui = s.get_eui
      dev_nonce = s.get_u16
      mic = s.get_u32
      
      return unless join_eui and dev_eui and dev_nonce and mic 
      
      self.new(join_eui, dev_eui, dev_nonce, mic)
      
    end
    
    attr_reader :join_eui, :dev_eui, :dev_nonce
    
    def initialize(join_eui, dev_eui, dev_nonce, mic) 
      @join_eui = join_eui
      @dev_eui = dev_eui
      @dev_nonce = dev_nonce
      @mic = mic
    end
    
    def encode
      result = OutputCodec.new.
        put_u8(type << 5).
        put_eui(join_eui).
        put_eui(dev_eui).
        put_u16(dev_nonce).
        put_u32(mic).
        output 
        
      result
    end
    
  end
  
  class JoinAccept < Frame
  
    @type = 1
  
    def self.decode(s)
      nil    
    end
  
    attr_reader :join_nonce, :net_id, :dev_addr, :rx_delay, :opt_neg, :rx1_dr_offset, :rx2_dr, :cflist
  
    def initialize(join_nonce, net_id, dev_addr, rx_delay, opt_neg, rx1_dr_offset, rx2_dr, cflist, mic)
      @join_nonce = join_nonce
      @net_id = net_id
      @dev_addr = dev_addr
      @rx_delay = rx_delay
      @opt_neg = opt_neg
      @rx1_dr_offset = rx1_dr_offset      
      @rx2_dr = rx2_dr      
      @cflist = cflist
      @mic = mic

      raise ArgumentError.new "cflist must be 0 or 16 bytes long" unless (cflist.size == 0 or cflist.size == 16)
      
    end
  
    def dl_settings
      (opt_neg ? 0x80 : 0x00 ) | ((rx1_dr_offset & 0x7) << 4) | (rx2_dr & 0xf) 
    end
  
    def encode
      OutputCodec.new.
        put_u8(type << 5).
        put_u24(join_nonce).
        put_u24(net_id).
        put_u32(dev_addr).
        put_u8(dl_settings).
        put_u8(rx_delay).
        put_bytes(cflist).
        put_u32(mic).
        output
    end
    
  end
  
  class RejoinRequest < Frame
  
    @type = 6
  
    def self.decode(s)
    
      rejoin_type = s.get_u8
      net_id = s.get_u24
      dev_eui = s.get_eui
      rj_count = s.get_u16
      mic = s.get_u32
      
      return unless rejoin_type and net_id and rj_count and mic
      
      self.new(rejoin_type, net_id, dev_eui, rj_count, mic)
      
    end
  
    attr_reader :rj_type, :net_id, :dev_eui, :rj_count
  
    def initialize(rj_type, net_id, dev_eui, rj_count, mic)
      @rj_type = rj_type
      @net_id = net_id
      @dev_eui = dev_eui
      @rj_count = rj_count
      @mic = mic
    end
    
    def encode
      OutputCodec.new.
        put_u8(type << 5).
        put_u8(rj_type).
        put_24(net_id).
        put_eui(dev_eui).
        put_u16(rj_count).
        put_u32(mic).
        output 
    end
  
  end
  
  class Data < Frame
  
    def self.decode(s)
      
      dev_addr = s.get_u32      
      fhdr = s.get_u8
      counter = s.get_u16
      
      return unless dev_addr and fhdr and counter

      adr = ( fhdr & 0x80 ) != 0
      adr_ack_req = ( fhdr & 0x40 ) != 0
      ack = ( fhdr & 0x20 ) != 0
      pending = ( fhdr & 0x10 ) != 0
      opts_len = ( fhdr & 0xf )
    
      opts = s.get_bytes(opts_len)

      if s.remaining > 4
        
        port = s.get_u8
      
        data = s.get_bytes(s.remaining - 4)
      
      else
      
        port = nil
        data = nil
      
      end
    
      mic = s.get_u32

      return unless mic
      
      if port == 0 and opts.size > 0
        log_debug{"discarding frame: cannot have port=0 and opts.size>0"}
        return
      end
  
      self.new(
        dev_addr,
        adr,
        adr_ack_req,
        ack,
        pending,
        counter,
        opts,          
        port,
        data,
        mic        
      )
    
    end
  
    def self.confirmed
      @confirmed
    end
    
    def confirmed
      self.class.send __method__
    end
  
    attr_reader :dev_addr, :adr, :adr_ack_req, :ack, :pending, :opts, :port, :data, :counter
  
    @type = nil
    
    def initialize(dev_addr, adr, adr_ack_req, ack, pending, counter, opts, port, data, mic)
      @dev_addr = dev_addr
      @adr = adr
      @adr_ack_req = adr_ack_req
      @ack = ack
      @pending = pending
      @counter = counter
      @opts = opts
      @port = port
      @data = data
      @mic = mic
    end
    
    def encode
    
      out = OutputCodec.new.
        put_u8(type << 5).
        put_u32(dev_addr).
        put_u8(
          (adr ? 0x80 : 0x00) |
          (adr_ack_req ? 0x40 : 0x00) |
          (ack ? 0x20 : 0x00) |
          (pending ? 0x10 : 0x00) |
          (opts.size & 0xf)
        ).
        put_u16(counter).
        put_bytes(opts)
        
      out.put_u8(port) if port
      out.put_bytes(data) if (port and data)
      
      out.put_u32(mic).output
        
    end
  
  end
  
  class DataUnconfirmedUp < Data
  
    @confirmed = false
    @type = 2
    
  end
  
  class DataConfirmedUp < Data
  
    @confirmed = true
    @type = 4
    
  end
  
  class DataUnconfirmedDown < Data
  
    @confirmed = false
    @type = 3
    
  end
  
  class DataConfirmedDown < Data
    
    @confirmed = true
    @type = 5
  
  end
  
end
