module Flora

  class MacCommand 
  
    @tag = nil

    @@subs = []
  
    def self.decode(s)
      self.new
    end
  
    def self.inherited(klass)
      if self == MacCommand
        @@subs << klass      
      else
        superclass.inherited(klass)
      end        
    end
  
    def self.tag
      @tag
    end
    
    def tag
      self.class.send __method__
    end
    
    def self.subs
      @@subs
    end
    
    def self.upstream
      @upstream
    end
    
    def self.tag_to_cls(tag)
      @@subs.detect{|cls|cls.tag == tag}
    end
    
    def name
      self.class.name.split("::").last
    end
    
    def to_h
      {
        type: name
      }
    end
    
    def encode(output="")  
      OutputCodec.new(output).put_u8(tag).output
    end
    
  end
  
  class ResetInd < MacCommand
  
    @tag = 1
    @upstream = true
    
    def self.decode(s)      
      
      version = s.get_u8
      
      return unless version
      
      self.new(version & 0xf)

    end
    
    attr_reader :minor
    
    def initialize(minor)
      @minor
    end
    
    def encode(output="")  
      OutputCodec.new(output).put_u8(tag).put_u8(minor & 0xf).output
    end
  
    def to_h
      {
        type: name,
        minor: minor
      }
    end
    
  end
  
  class ResetConf < MacCommand
  
    @tag = 1
    @upstream = false
    
    def self.decode(s)
    
      version = s.get_u8
      
      return unless version
      
      self.new(version & 0xf)      
      
    end
    
    attr_reader :minor
    
    def initialize(minor)
      @minor = minor
    end
    
    def encode(output="")  
      OutputCodec.new(output).put_u8(tag).put_u8(minor & 0xf).output
    end

    def to_h
      {
        type: name,
        minor: minor
      }
    end
  
  end
  
  class LinkCheckReq < MacCommand
  
    @tag = 2
    @upstream = true
    
  end
  
  class LinkCheckAns < MacCommand
  
    @tag = 2
    @upstream = false
    
    def self.decode(s)
      
      margin = s.get_u8
      gw_cnt = s.get_u8
    
      return unless margin and gw_cnt
    
      self.new(margin, gw_cnt)
      
    end
    
    attr_reader :margin, :gw_cnt
    
    def initialize(margin, gw_cnt)
      @margin = margin
      @gw_cnt = gw_cnt
    end
    
    def encode(output="")  
      OutputCodec.new(output).put_u8(tag).put_u8(margin).put_u8(gw_cnt).output
    end

    def to_h
      {
        type: name,
        margin: margin,
        gw_cnt: gw_cnt
      }
    end
  
  end
  
  class LinkADRReq < MacCommand
  
    @tag = 3
    @upstream = false
    
    def self.decode(s)
      
      rate_and_power = s.get_u8
      ch_mask = s.get_u16
      redundancy = s.get_u8
      
      return unless rate_and_power and ch_mask and redundancy
      
      rate = rate_and_power >> 4
      power = rate_and_power & 0xf
      ch_mask_cntl = (redundancy >> 4) & 0x7
      nb_trans = redundancy & 0xf
      
      self.new(rate, power, ch_mask, ch_mask_cntl, nb_trans)
        
    end
    
    attr_reader :data_rate, :tx_power, :ch_mask, :ch_mask_cntl, :nb_trans
    
    def initialize(data_rate, tx_power, ch_mask, ch_mask_cntl, nb_trans)
      @data_rate = data_rate
      @tx_power = tx_power
      @ch_mask = ch_mask
      @ch_mask_cntl = ch_mask_cntl
      @nb_trans = nb_trans
    end
    
    def encode(output="")
      OutputCodec.new(output).
        put_u8(tag).
        put_u8(data_rate << 4 | (tx_power & 0xf)).
        put_u16(ch_mask).
        put_u8((ch_mask_cntl & 0x7) << 4 | (nb_trans & 0xf)).
        output
    end
  
    def to_h
      {
        type: name,
        data_rate: data_rate,
        tx_power: tx_power,
        ch_mask: ch_mask,
        ch_mask_cntl: ch_mask_cntl,
        nb_trans: nb_trans
      }
    end
  
  end
  
  class LinkADRAns < MacCommand
  
    @tag = 3
    @upstream = true
    
    def self.decode(s)
    
      status = s.get_u8
      
      return unless status
    
      power_ack = (status & 0x4) == 0x4
      data_rate_ack = (status & 0x2) == 0x2
      channel_mask_ok = (status & 0x1) == 0x1
      
      self.new(power_ack, data_rate_ack, channel_mask_ok)
    
    end
    
    attr_reader :power_ack, :data_rate_ack, :channel_mask_ok
    
    def initialize(power_ack, data_rate_ack, channel_mask_ok)
      @power_ack = power_ack
      @data_rate_ack = data_rate_ack
      @channel_mask_ok = channel_mask_ok
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(power_ack ? 0x4 : 0x0 | data_rate_ack ? 0x2 : 0 | channel_mask_ok ? 0x1 : 0).output        
    end
  
    def to_h
      {
        type: name,
        power_ack: power_ack,
        data_rate_ack: data_rate_ack,
        channel_mask_ok: channel_mask_ok
      }
    end
  
  end
  
  class DutyCycleReq < MacCommand
  
    @tag = 4
    @upstream = false
    
    def self.decode(s)
    
      duty_cycle_pl = s.get_u8
      
      return unless duty_cycle_pl
      
      self.new(duty_cycle_pl & f)
      
    end
    
    attr_reader :max_dcycle
    
    def initialize(max_dcycle)
      @max_dcycle = max_dcycle
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(max_dcycle & 0xf).output
    end
  
    def to_h
      {
        type: name,
        max_dcycle: max_dcycle
      }
    end
  
  end
  
  class DutyCycleAns < MacCommand
  
    @tag = 4
    @upstream = true
    
  end
  
  class RXParamSetupReq < MacCommand
  
    @tag = 5
    @upstream = false
    
    def self.decode(s)
    
      dl_settings = s.get_u8
      freq = s.get_u24
      
      return unless dl_settings and freq
      
      rx1_dr_offset = (dl_settings >> 4)  & 0xf
      rx2_dr = dl_settings & 0xf
      
      self.new(rx1_dr_offset, rx2_dr, freq * 100)
    
    end
    
    attr_reader :rx1_dr_offset, :rx2_dr, :freq
    
    def initialize(rx1_dr_offset, rx2_dr, freq)
      @rx1_dr_offset = rx1_dr_offset
      @rx2_dr = rx2_dr
      @freq = freq
    end
    
    def encode(output="")
      OutputCodec.new(output).
        put_u8(tag).
        put_u8((rx1_dr_offset & 0xf) << 4 | rx2_dr & 0xf).
        put_u24(freq / 100).
        output
    end
    
    def to_h
      {
        type: name,
        rx1_dr_offset: rx1_dr_offset,
        rx2_dr: rx2_dr,
        freq: freq
      }
    end
  
  end
  
  class RXParamSetupAns < MacCommand
  
    @tag = 5
    @upstream = true
    
    def self.decode(s)
    
      status = s.get_u8
      
      return unless status
      
      rx1_dr_offset_ack = (status & 0x4) == 0x4
      rx2_dr_ack = (status & 0x2) == 0x2 
      channel_ack = (status & 0x1) == 0x1
    
      self.new(rx1_dr_offset_ack, rx2_dr_ack, channel_ack)

    end
    
    attr_reader :rx1_dr_offset_ack, :rx2_dr_ack, :channel_ack
    
    def initialize(rx1_dr_offset_ack, rx2_dr_ack, channel_ack)
      @rx1_dr_offset_ack = rx1_dr_offset_ack
      @rx2_dr_ack = rx2_dr_ack
      @channel_ack = channel_ack
    end
    
    def encode(output="")
      OutputCodec.new(output).
        put_u8(tag).
        put_u8(rx1_dr_offset_ack ? 0x4 : 0 | rx2_dr_ack ? 0x2 : 0 | channel_ack ? 0x1 : 0).
        output
    end
    
    def to_h
      {
        type: name,
        rx1_dr_offset_ack: rx1_dr_offset_ack,
        rx2_dr_ack: rx2_dr_ack,
        channel_ack: channel_ack
      }
    end
  
  end
  
  class DevStatusReq < MacCommand
  
    @tag = 6
    @upstream = false
    
  end
  
  class DevStatusAns < MacCommand
  
    @tag = 6
    @upstream = true
    
    def self.decode(s)
      
      battery = s.get_u8
      margin = s.get_u8
      
      return unless battery and margin
      
      self.new(battery, margin)
      
    end
    
    attr_reader :battery, :margin
    
    def initialize(battery, margin)
      @battery = battery
      @margin = margin
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(battery).put_u8(margin & 0x3f).output
    end
  
    def to_h
      {
        type: name,
        battery: battery,
        margin: margin
      }
    end  

  end
  
  class NewChannelReq < MacCommand
  
    @tag = 7
    @upstream = false
  
    def self.decode(s)
    
      ch_index = s.get_u8
      freq = s.get_u24
      dr_rate = s.get_u8
      
      return unless ch_index and freq and dr_rate      
      
      self.new(ch_index, freq * 100, dr_rate >> 4, dr_rate & 0xf)        
      
    end
    
    attr_reader :ch_index, :freq, :max_dr, :min_dr
  
    def initialize(ch_index, freq, max_dr, min_dr)
      @ch_index = ch_index
      @freq = freq
      @max_dr = max_dr
      @min_dr = min_dr
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(ch_index).put_u24(freq / 100).put_u8(max_dr << 4 | min_dr & 0xf).output
    end
  
    def to_h
      {
        type: name,
        ch_index: ch_index,
        freq: freq,
        max_dr: max_dr,
        min_dr: min_dr
      }
    end
  
  end
  
  class NewChannelAns < MacCommand
  
    @tag = 7
    @upstream = true
    
    def self.decode(s)
      
      status = s.get_u8
      
      return unless status
      
      self.new(
        (status & 0x2) == 0x2,
        (status & 0x1) == 0x1
      )
      
    end
    
    attr_reader :dr_ok, :freq_ok
    
    def initialize(dr_ok, freq_ok)
      @dr_ok = dr_ok
      @freq_ok = freq_ok
    end
    
    def encode(output="")  
      OutputCodec.new(output).put_u8(tag).put_u8(dr_ok ? 0x2 : 0 | freq_ok ? 0x1 : 0).output
    end
  
    def to_h
      {
        type: name,
        dr_ok: dr_ok,
        freq_ok: freq_ok
      }
    end
  
  end
  
  class RXTimingSetupReq < MacCommand
  
    @tag = 8
    @upstream = false
    
    def self.decode(s)
    
      setting = s.get_u8
      
      return unless setting
      
      self.new(setting & f)
      
    end
    
    attr_reader :del
    
    def initialize(del)
      @del = del
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(del & 0xf).output
    end
    
    def to_h
      {
        type: name,
        del: del
      }
    end
    
  end
  
  class RXTimingSetupAns < MacCommand
  
    @tag = 8
    @upstream = true
    
  end
  
  class TXParamSetupReq < MacCommand
  
    @tag = 9
    @upstream = false
    
    def self.decode(s)
    
      eirp_dwell_time = s.get_u8
      
      return unless eirp_dwell_time
      
      self.new(
        (eirp_dwell_time & 0x20) == 0x20,
        (eirp_dwell_time & 0x10) == 0x10,          
        eirp_dwell_time & 0xf
      )
      
    end
    
    attr_reader :down, :up, :max_eirp
    
    def initialize(down, up, max_eirp)
      @up = up
      @ul_dwell = ul_dwell
      @max_eirp = max_eirp
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(
        (down ? 0x20 : 0) | (up ? 0x10 : 0) | (max_eirp & 0xf)
      ).output
    end
  
    def to_h
      {
        type: name,
        up: up,
        ul_dwell: ul_dwell,
        max_eirp: max_eirp
      }
    end
  
  end
  
  class TXParamSetupAns < MacCommand
  
    @tag = 9
    @upstream = true
  
  end
  
  class DlChannelReq < MacCommand
    
    @tag = 10
    @upstream = false
    
    def self.decode(s)
      
      ch_index = s.get_u8
      freq = s.get_u24
      
      return unless ch_index and freq
      
      self.new(ch_index, freq * 100)
      
    end
    
    attr_reader :ch_index, :freq
    
    def initialize(ch_index, freq)
      @ch_index = ch_index
      @freq = freq
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(ch_index).put_u24(freq/100).output
    end
  
    def to_h
      {
        type: name,
        ch_index: ch_index,
        freq: freq
      }
    end
  
  end
  
  class DlChannelAns < MacCommand
  
    @tag = 10
    @upstream = true
    
    def self.decode(s)
      
      setting = s.get_u8
      
      return unless setting
      
      self.new(
        (setting & 2) == 2,
        (setting & 1) == 1
      )

    end
    
    attr_reader :uplink_exists, :freq_ok
    
    def initialize(uplink_exists, freq_ok)
      @uplink_exists = uplink_exists
      @freq_ok = freq_ok
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(
        (uplink_exists ? 0x2 : 0) | (freq_ok ? 0x1 : 0)
      ).output
    end
  
    def to_h
      {
        type: name,
        uplink_exists: uplink_exists,
        freq_ok: freq_ok
      }
    end
  
  end
  
  class RekeyInd < MacCommand
  
    @tag = 11
    @upstream = true
    
    def self.decode(s)
      
      version = s.get_u8
      
      return unless version
      
      self.new(version & 0xf)
      
    end
  
    attr_reader :version
    
    def initialize(version)
      @version = version
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(version & 0xf).output
    end
  
    def to_h
      {
        type: name,
        version: version
      }
    end
  
  end
  
  class RekeyConf < MacCommand
  
    @tag = 11
    @upstream = false
    
    def self.decode(s)
      
      version = s.get_u8
      
      return unless version
        
      self.new(version & 0xf)
      
    end
  
    attr_reader :version
    
    def initialize(version)
      @version = version
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(version & 0xf).output
    end
  
    def to_h
      {
        type: name,
        version: version
      }
    end
  
  end
  
  class ADRParamSetupReq < MacCommand
  
    @tag = 12
    @upstream = false
  
    def self.decode(s)
      
      adr_param = s.get_u8
      
      return unless adr_param
      
      self.new(adr_param >> 4, adr_param & 0xf)
      
    end
      
    attr_reader :limit_exp, :delay_exp
    
    def initialize(limit_exp, delay_exp)
      @limit_exp = limit_exp
      @delay_exp = delay_exp
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8((limit_exp << 4) | (delay_exp & 0xf)).output
    end
  
    def to_h
      {
        type: name,
        limit_exp: limit_exp,
        delay_exp: delay_exp
      }
    end
  
  end
  
  class ADRParamSetupAns < MacCommand
  
    @tag = 12
    @upstream = true
  
  end
  
  class DeviceTimeReq < MacCommand
  
    @tag = 13
    @upstream = true
  
  end
  
  class DeviceTimeAns < MacCommand
  
    @tag = 13
    @upstream = false
    
    def self.decode(s)
      
      seconds = s.get_u32
      fractions = s.get_u8
      
      return unless seconds and fractions
      
      self.new(seconds, fractions)
      
    end
    
    attr_reader :seconds, :fractions
    
    def initialize(seconds, fractions)
      @seconds = seconds
      @fractions = fractions
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u32(seconds).put_u8(fractions).output
    end
  
    def to_h
      {
        type: name,
        seconds: seconds,
        fractions: fractions
      }
    end
    
  end
  
  class ForceRejoinReq < MacCommand
  
    @tag = 14
    @upstream = false
    
    def self.decode(s)
      
      setting = s.get_u16
      
      return unless setting
      
      period = (setting >> 11) & 7
      max_retries = (setting >> 8) & 7
      rejoin_type = (setting >> 4) & 7
      dr = setting & 0xf
      
      self.new(period, max_retries, rejoin_type, dr)
      
    end
    
    attr_reader :period, :max_retries, :rejoin_type, :dr
    
    def initialize(period, max_retries, rejoin_type, dr)
      @period = period
      @max_retries = max_retries
      @rejoin_type = rejoin_type
      @dr = dr      
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u16(
        ((period & 7) << 11) | ((max_retries & 7) << 8) | ((rejoin_type & 0x7) << 4) | (dr & 0xf)
      ).output
    end
  
    def to_h
      {
        type: name,
        period: period,
        max_retries: max_retries,
        rejoin_type: rejoin_type,
        dr: dr
      }
    end
  
  end
  
  class RejoinParamSetupReq < MacCommand
  
    @tag = 15
    @upstream = false
    
    def self.decode(s)
    
      setting = s.get_u8
      
      return unless setting
      
      self.new(setting >> 4, setting & 0xf)
      
    end
    
    attr_reader :max_time, :max_count
    
    def initialize(max_time, max_count)
      @max_time = max_time
      @max_count = max_count
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8((max_time << 4) | (max_count & 0xf)).output
    end
  
    def to_h
      {
        type: name,
        max_time: max_time,
        max_count: max_count
      }
    end
  
  end
  
  class RejoinParamSetupAns < MacCommand
  
    @tag = 15
    @upstream = true
    
    def self.decode(s)
      
      status = s.get_u8
      
      return unless status
      
      self.new((status & 1) == 1)
      
    end
    
    attr_reader :time_ok
    
    def initialize(time_ok)
      @time_ok = time_ok
    end
    
    def encode(output="")
      OutputCodec.new(output).put_u8(tag).put_u8(time_ok ? 1 : 0).output
    end
  
    def to_h
      {
        type: name,
        time_ok: time_ok
      }
    end
  
  end
  
end
