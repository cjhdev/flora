require 'time'

module Flora

  # mixed-in to Device
  module DeviceHelpers
  
    [
      :dev_nonce,
      :join_nonce,
      :up_counter,
      :dev_addr,
      :minor,
      :ready_at,
      
      :rx_delay,
      :rx1_dr_offset,
      :rx2_dr,
      :rx2_freq,
      :adr_ack_limit,
      :adr_ack_delay,
      
      :join_gw_channels
      
    ].each do |m|
    
      define_method m do 
        @record[m]
      end
    
    end
    
    # device name is dev_eui in strict base64 representation
    def name
      @record[:dev_eui]
    end
    
    def dev_eui
      @record[__method__].unpack("m").first
    end
    
    def join_eui
      @record[__method__].unpack("m").first if @record[__method__]
    end
    
    def join_request_frame
      @record[__method__].unpack("m").first if @record[__method__]
    end
    
    def data_up_frame
      @record[__method__].unpack("m").first if @record[__method__]
    end
    
    # a device record is considered joined if the join_eui is recorded
    def joined?
      not join_eui.nil?
    end

    def use_apps?
      not(@record[:keys][:apps].nil?)
    end
    
    def ready_at?(rx_time)
      ready_at.nil? || rx_time >= Time.at(ready_at)
    end
    
    def clear_data_counter!
     @redis.del(rk_first_data(name))
    end
    
    def clear_join_counter!
     @redis.del(rk_first_join(name))
    end
    
    def clear_nwk_and_app_counter!
      @redis.multi do
        @redis.del(rk_nwk_counter(name))
        @redis.del(rk_app_counter(name))
      end
    end
    
    def increment_nwk_counter!
      @redis.incr(rk_nwk_counter(name))
    end
    
    def increment_app_counter!
      @redis.incr(rk_app_counter(name))
    end
    
    def app_counter
      @redis.get(rk_app_counter(name)).to_i
    end
    
    def nwk_counter
      @redis.get(rk_nwk_counter(name)).to_i
    end
  
    def save_record!
      @redis.set(rk_eui(name), JSON.to_json(@record))
    end
    
    def save_return_path!(**args)
      @redis.sadd(rk_return_path(name), JSON.to_json(args))        
    end
    
    def clear_return_path!
      @redis.del(rk_return_path(name))
    end
    
    def mic_data_up(counter, data, rate, ch_index, freq, **opts)    
      
      micable = data.slice(0..-5)
      
      b0 = init_up_b0(counter, micable.size)
      
      micF = @sm.mic(:fnwksint, b0, micable)
      
      if minor > 0
      
        confirm_counter = opts[:confirm_counter]||0
        
        b1 = init_up_b1(confirm_counter, rate, ch_index, counter, micable.size)
      
        micS = @sm.mic(:snwksint, b1, micable)
    
        ((micF & 0xffff) << 16) | (micS & 0xffff)
        
      else
      
        micF
      
      end
    
    end
  
    def init_up_a(counter, i=1)
      
      OutputCodec.new.
        put_u8(1).
        put_u32(0).
        put_u8(0).
        put_u32(dev_addr).
        put_u32(counter).
        put_u8(0).
        put_u8(i).
        output
      
    end
    
    def init_down_a(counter, i=1)
      
      OutputCodec.new.
        put_u8(1).
        put_u32(0).
        put_u8(1).
        put_u32(dev_addr).
        put_u32(counter).
        put_u8(0).
        put_u8(i).
        output
      
    end
    
    def init_down_b0(confirm_counter, counter, len)
    
      OutputCodec.new.
        put_u8(0x49).
        put_u16(confirm_counter).
        put_u16(0).
        put_u8(1).
        put_u32(dev_addr).
        put_u32(counter).
        put_u8(0).
        put_u8(len).
        output
      
    end
    
    def init_up_b0(counter, len)
    
      OutputCodec.new.
        put_u8(0x49).
        put_u32(0).
        put_u8(0).
        put_u32(dev_addr).
        put_u32(counter).
        put_u8(0).
        put_u8(len).
        output
      
    end
    
    def init_up_b1(confirm_counter, rate, ch_index, counter, len)
    
      OutputCodec.new.
        put_u8(0x49).
        put_u16(confirm_counter).
        put_u8(rate).
        put_u8(ch_index).
        put_u8(0).
        put_u32(dev_addr).
        put_u32(counter).
        put_u8(0).
        put_u8(len).
        output
    
    end
    
    # calculate transmit time for given size, sf, bw, and direction
    def transmit_time(sf, bw, size, upstream=true)
      
      low_rate_optimise = ((bw == 125) and (sf > 10))
      
      ts = symbol_period(sf, bw)
      tpre = (ts * 12) +  (ts / 4);
      
      numerator = (8 * size) - (4 * sf) + 28 + ( upstream ? 16 : 0 ) - 20;
      denom = 4 * (sf - ( low_rate_optimise ? 2 : 0 ));

      npayload = 8 + ((((numerator / denom) + (((numerator % denom) != 0) ? 1 : 0)) * (1 + 4)));

      tpayload = npayload * ts
      
      tpacket = tpre + tpayload
      
      tpacket
      
    end
    
    def symbol_period(sf, bw)
      ((1 << sf) * 1000000) / bw
    end
  
    SIZE_OF_UPLINK_HISTORY = 20
  
    def save_uplink_history!(**args)
      @redis.multi do
        key = rk_uplink_history(name)
        @redis.sadd(key, JSON.to_json(args))
        @redis.trim(key, SIZE_OF_UPLINK_HISTORY)
      end
    end
    
    def full_uplink_history?
      @redis.scard(rk_uplink_history(name)) == SIZE_OF_UPLINK_HISTORY
    end
    
    def due_for_adr?
    
      if adr_settings.ack_pending
        true      
      elsif adr_settings.ack_counter
        ((up_counter - adr_settings.ack_counter) > (3*SIZE_OF_UPLINK_HISTORY))        
      else
        full_uplink_history?
      end
      
    end
      
    def clear_uplink_history!
      @redis.del(rk_uplink_history(name))
    end
    
    # SNR minimums for each SF
    SF_TO_MIN_SNR = {
      6 => -5,
      7 => -7.5,
      8 => -10,
      9 => -12.5,
      10 => -15,
      11 => -17.5,
      12 => -20
    }
    
    def min_snr(sf)
      SF_TO_MIN_SNR[sf]      
    end
    
    def snr_margin(sf, snr)
      snr - SF_TO_MIN_SNR[sf]
    end
  
    # work out fraction of missing packets based on sequence numbers in uplink history
    def calculate_fraction_of_missing_sequence(sorted_counters)
      missing_counters = sorted_counters - Range.new(sorted_counters.first, sorted_counters.last).to_a
      missing_counters.size / (sorted_counters.size + missing_counters.size)
    end
    
    # update adr settings cache from redis
    def load_adr_settings!
      if rec = @redis.get(rk_adr_setting(name))
        @adr_settings = ADRSettings.new(**JSON.from_json(rec))        
      else
        @adr_settings = ADRSettings.new(
          rate:   0,
          power:  0,
          min_rate: 0,
          max_rate: 5,
          min_power: 5,
          max_power: 0,
          nb_trans: 1,
          ack_pending: false
        )
      end
    end
    
    # save adr settings cache to redis
    def save_adr_settings!
      @redis.set(rk_adr_setting(name), JSON.to_json(@adr_settings.to_h))
      nil
    end
  
  end
  
  ADRSettings = Struct.new(:ack_pending, :ack_counter, :ack_trials, :rate, :power, :min_rate, :max_rate, :min_power, :max_power, :nb_trans, keyword_init: true)
  
end
