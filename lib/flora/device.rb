require_relative 'device_helpers'

Thread.abort_on_exception = true

module Flora

  class Device

    # seconds after which the downlink will be selected
    DL_SELECT_WINDOW = 0.3

    # seconds after which a join can occur (again)
    JOIN_WINDOW = 6

    SNR_THRESHOLD = 5.0

    include LoggerMethods
    include DeviceHelpers
    include RedisKeys

    attr_reader :redis, :sm, :plan, :record, :net_id, :adr_settings

    def initialize(**opts)

      @logger = opts[:logger]||NULL_LOGGER
      @record = opts[:record]||{}
      @sm = SecurityModule.new(@record[:keys], logger: @logger)
      @redis = opts[:redis]
      @plan = Region.by_name(@record[:region]).new(
        rx_delay: rx_delay,
        rx1_dr_offset: rx1_dr_offset,
        rx2_dr: rx2_dr,
        rx2_freq: rx2_freq,
        adr_ack_limit: adr_ack_limit,
        adr_ack_delay: adr_ack_delay,
        gw_channels: join_gw_channels
      )

      @defer = opts[:defer]
      @net_id = opts[:net_id]||0
      @adr_settings = nil

      raise ArgumentError.new "defer argument is required" unless @defer

    end

    def process_join_request(event)

      params = plan.exchange_params(event.freq, event.sf, event.bw)

      if params.nil?

        log_debug { "frame_rejected: freq, sf, or bw not valid for channel plan" }
        return

      end

      if dev_nonce

        if (dev_nonce > event.frame.dev_nonce) and (minor > 0)

          log_debug { "frame_rejected: devNonce '#{event.frame.dev_nonce}' already used" }
          return

        elsif dev_nonce == event.frame.dev_nonce

          if up_counter

            log_debug { "frame_rejected: dev_nonce has been replayed after data frame received" }
            return

          end

          # speed up validation if cache is available
          if join_request_frame

            if event.data != join_request_frame

              log_debug {"frame_rejected: duplicate join accept does not match the original"}
              return

            end

          else

            if @sm.mic(:nwk, event.data.slice(0..-5)) != event.frame.mic

              log_debug {"frame_rejected: mic failed"}
              return

            end

          end

          save_return_path!(
            time: event.rx_time.to_f,
            snr: event.snr,
            rssi: event.rssi,
            gw_id: event.gw_id,
            gw_param: event.gw_param.to_h
          )

          # indicate duplicate accepted
          return self unless ready_at?(event.rx_time)

        end

      end

      if dev_nonce != event.frame.dev_nonce

        if @sm.mic(:nwk, event.data.slice(0..-5)) != event.frame.mic

          log_debug {"frame_rejected: mic failed"}
          return

        end

        save_return_path!(
            time: event.rx_time.to_f,
            snr: event.snr,
            rssi: event.rssi,
            gw_id: event.gw_id,
            gw_param: event.gw_param.to_h
        )

        # ensure a winner to the race (and indicate duplicate accepted)
        return self if not(first_event?(rk_first_join(name), event.frame.dev_nonce))

      end

      @record[:dev_nonce] = event.frame.dev_nonce
      @record[:join_eui] = [event.frame.join_eui].pack("m0")

      if minor > 0
        @sm.derive_keys2(join_nonce, join_eui, dev_nonce, dev_eui)
      else
        @sm.derive_keys(join_nonce, net_id, dev_nonce)
      end

      @record[:ready_at] = (event.rx_time + JOIN_WINDOW).to_f
      @record[:join_request_frame] = [event.data].pack("m0")

      @record.delete(:up_counter)
      @record.delete(:data_up_frame)

      # take channels from this gateway
      @record[:join_gw_channels] = event.gw_channels

      # we have to refresh the region/plan
      plan.update_channels(event.gw_channels)

      clear_nwk_and_app_counter!
      clear_uplink_history!
      clear_data_counter!
      save_record!

      response = JoinAccept.new(
        join_nonce,
        net_id,
        dev_addr,
        plan.rx_delay,
        (minor > 0),
        plan.rx1_dr_offset,
        plan.rx2_dr,
        plan.cflist,
        0
      ).encode.slice!(0..-5)

      if minor > 0

        hdr = OutputCodec.new.put_u8(0xff).put_eui(join_eui).put_u16(dev_nonce).output

        OutputCodec.new(response).put_u32(@sm.mic(:jsint, hdr, response))

      else

        OutputCodec.new(response).put_u32(@sm.mic(:nwk, response))

      end

      response.concat @sm.ecb_decrypt(:nwk, response.slice!(1..-1))

      if block_given?

        process_time = Time.now - event.rx_time

        @defer.on_timeout((process_time > DL_SELECT_WINDOW) ? 0 : DL_SELECT_WINDOW - process_time) do

          path, all_path = select_return_path!(event.rx_time)

          yield(
            GatewayDownEvent.new(

              gw_id: path[:gw_id],
              gw_param: path[:gw_param],

              data: response,

              dev_eui: dev_eui,

              rx_delay: plan.ja_delay,
              rx_param: params
            )
          )

          yield(
            ActivationEvent.new(
              dev_eui: dev_eui,
              join_eui: join_eui,
              dev_addr: dev_addr,
              rx_time: event.rx_time,
              freq: event.freq,
              sf: event.sf,
              bw: event.bw,
              dev_nonce: dev_nonce,
              join_nonce: join_nonce,
              rate: params.up.rate,
              gws: all_path.map do |rec|
                rec.delete(:gw_param)
                rec[:margin] = snr_margin(event.sf, event.snr)
                rec[:gw_id] = rec[:gw_id].unpack("m").first
                rec
              end
            )
          )

          yield(DeviceUpdateEvent.new(dev_eui: dev_eui))

        end

      else
        clear_return_path!
      end

      self

    end

    def process_data_up(event)

      params = plan.exchange_params(event.freq, event.sf, event.bw)

      if params.nil?

        log_debug{"frame_rejected: freq, sf, or bw not valid for channel plan"}
        return

      end

      if not joined?

        log_debug{"frame_rejected: device not joined"}
        return

      end

      counter = derive_up_counter(event.frame.counter)

      if up_counter

        if up_counter == counter

          if ready_at?(event.rx_time)

            log_debug{"frame_rejected: duplicate received after #{plan.rx_delay}s"}
            return

          end

          # speed up validation if cache is available
          if data_up_frame

            if data_up_frame != event.data

              log_debug{"frame_rejected: duplicate frame does not match original"}
              return

            end

          else

            if mic_data_up(counter, event.data, params.up.rate, params.up.chan, event.freq) != event.frame.mic

              log_debug{"frame_rejected: mic failed"}
              return

            end

          end

          save_return_path!(
            time: event.rx_time.to_f,
            snr: event.snr,
            rssi: event.rssi,
            gw_id: event.gw_id,
            gw_param: event.gw_param.to_h
          )

          return self

        elsif up_counter > counter

          log_debug { "frame_rejected: counter '#{counter}' already used" }
          return

        else

          unless ready_at?(event.rx_time)

            log_debug{"frame_rejected: data received too soon after previous data frame"}
            return

          end

        end

      else

        if ready_at?(event.rx_time)

          log_debug{"frame_rejected: data received too soon after previous join request frame"}
          return

        end

      end

      if mic_data_up(counter, event.data, params.up.rate, params.up.chan, event.freq) != event.frame.mic

        log_debug{"frame_rejected: mic failed"}
        return

      end

      save_return_path!(
        time: event.rx_time.to_f,
        snr: event.snr,
        rssi: event.rssi,
        gw_id: event.gw_id,
        gw_param: event.gw_param.to_h
      )

      # ensure a winner to the race
      return if not(first_event?(rk_first_data(name), counter))

      @record[:up_counter] = counter

      @record[:ready_at] = (event.rx_time + plan.rx_delay + 1).to_f
      @record[:data_up_frame] = [event.data].pack("m0")

      save_record!

      opts = nil
      data = nil

      if event.frame.port and event.frame.port == 0

        opts = @sm.ctr(:nwksenc, init_up_a(counter), event.frame.data)

      elsif minor > 0

        opts = @sm.ctr(:nwksenc, init_up_a(counter, 0), event.frame.opts)

      else

        opts = event.frame.opts

      end

      if event.frame.port and event.frame.port > 0

        data = (use_apps? or (minor == 0)) ? @sm.ctr(:apps, init_up_a(counter), event.frame.data) : event.frame.data

      end

      rx_mac_commands = MacCommandDecoder.new(logger: @logger).decode_up(opts)

      if block_given?

        process_time = Time.now - event.rx_time

        # shift to event worker pool after timeout
        @defer.on_timeout((process_time > DL_SELECT_WINDOW) ? 0 : DL_SELECT_WINDOW - process_time) do

          path, all_path = select_return_path!(event.rx_time)

          # keep track of successive frames when device is in ADR mode
          if event.frame.adr

            save_uplink_history!(counter: counter, snr: path[:snr], num_gw: all_path.size)

          else

            clear_uplink_history!

          end

          opts = ""
          battery_level = nil
          device_margin = nil

          load_adr_settings!

          rx_mac_commands.each do |cmd|

            case cmd
            when ResetInd

              ans = ResetConf.new(minor)
              log_info { "mac command: #{JSON.to_json(cmd.to_h)} answered by #{JSON.to_json(ans.to_h)}" }
              ans.encode(opts)

            when LinkCheckReq

              ans = LinkCheckAns.new(all_path.size, snr_margin(event.sf, path[:snr]))
              log_info { "mac command: #{JSON.to_json(cmd.to_h)} answered by #{JSON.to_json(ans.to_h)}" }
              ans.encode(opts)

            when RekeyInd

              ans = RekeyConf.new(minor)
              log_info { "mac command: #{JSON.to_json(cmd.to_h)} answered by #{JSON.to_json(ans.to_h)}" }
              ans.encode(opts)

            when DeviceTimeReq

              # GPS epoch 1980 Jan 6 0:0:0
              _system_time = (Time.now - 315964800).utc
              # fixme 1/256 fractions

              ans = DeviceTimeAns.new(_system_time.to_i, 0)
              log_info { "mac command: #{JSON.to_json(cmd.to_h)} answered by #{JSON.to_json(ans.to_h)}" }
              ans.encode(opts)

            when LinkADRAns

              log_info { "mac command: #{JSON.to_json(cmd.to_h)} to answer <orig>" }

              adr_settings.ack_pending = false

            when DutyCycleAns, RXParamSetupAns, NewChannelAns, RXTimingSetupAns, TXParamSetupAns, DlChannelAns, ADRParamSetupAns, DeviceTimeAns, RejoinParamSetupAns

              log_info { "mac command: unexpected #{JSON.to_json(cmd.to_h)}" }

            when DevStatusAns

              battery_level = cmd.battery
              device_margin = cmd.margin
              log_info { "mac command: #{JSON.to_json(cmd.to_h)}" }
            end

          end

          # process ADR

          if event.frame.adr_ack_req or due_for_adr?

            log_info { "processing adr" }

            # this should already be sorted by order of insertion
            sorted_history = @redis.smembers(rk_uplink_history(name)).map{|s|JSON.from_json(s)}

            # algorithm uses the max snr instead of median or mean
            # since it assumes the maximum is an indication of a
            # transmission that has not been interfered with by other devices
            best_snr_record = sorted_history.max_by{|rec|rec[:snr]}
            best_snr = best_snr_record[:snr]

            # fudge factor
            installation_margin = 10.0

            # fraction of lost packets
            packet_loss = calculate_fraction_of_missing_sequence(sorted_history.map{|rec|rec[:counter]})

            # if full history is available, adjust redundancy according to losses
            if sorted_history.size == SIZE_OF_UPLINK_HISTORY

              adr_settings.nb_trans = 1 unless (1..3).include? adr_settings.nb_trans

              if packet_loss < 0.05
                adr_settings.nb_trans = [0,1,1,2][adr_settings.nb_trans]
              elsif packet_loss < 0.1
                adr_settings.nb_trans = [0,1,2,2][adr_settings.nb_trans]
              elsif packet_loss < 0.3
                adr_settings.nb_trans = [0,2,3,3][adr_settings.nb_trans]
              else
                adr_settings.nb_trans = [0,3,3,3][adr_settings.nb_trans]
              end

            end

            # calculate margin according to the last received spreading factor
            margin = best_snr - installation_margin - min_snr(event.sf)

            step = (margin / 3.0).to_i

            adr_settings.rate = params.up.rate

            # reduce step to zero by adjusting rate and power
            while step != 0 do

              if step > 0

                if adr_settings.rate < adr_settings.max_rate

                  adr_settings.rate += 1

                elsif adr_settings.power < adr_settings.min_power

                  adr_settings.power += 1

                else

                  break

                end

                step -= 1

              elsif step < 0 and adr_settings.max_power > 0

                adr_settings.power -= 1
                step += 1

              end

            end

            adr_settings.ack_pending = true
            adr_settings.ack_counter = counter

            plan.adr_mask.each do |mask|

              req = LinkADRReq.new(adr_settings.rate, adr_settings.power, mask.ch_mask, mask.ch_mask_cntl, adr_settings.nb_trans)

              log_info { "adr result #{JSON.to_json(req.to_h)}" }

              req.encode(opts)

            end

          end

          save_adr_settings!

          if opts.size > 15

            opts = @sm.ctr(:nwksenc, init_down_a(nwk_counter), opts)

          elsif minor > 0

            opts = @sm.ctr(:nwksenc, init_down_a(nwk_counter, 0), opts)

          end

          # downstream message is required
          if event.frame.adr_ack_req or not(opts.empty?) or event.frame.confirmed

            response_port = nil

            output = DataUnconfirmedDown.new(
              dev_addr,
              false, false, false, false,
              nwk_counter,
              (opts.size < 16) ? opts : "",
              (opts.size > 15) ? 0 : response_port,
              (opts.size > 15) ? opts : nil,
              0
            ).encode.slice!(0..-5)

            b0 = init_down_b0(0, nwk_counter, output.size)

            OutputCodec.new(output).put_u32(@sm.mic(:snwksint, b0, output))

            increment_nwk_counter!

            yield(
              GatewayDownEvent.new(

                gw_id: path[:gw_id],
                gw_param: path[:gw_param],

                data: output,

                dev_eui: dev_eui,

                rx_delay: plan.ja_delay,
                rx_param: params
              )
            )

          end

          # data event for application
          yield(
            DataUpEvent.new(
              dev_eui: dev_eui,
              rx_time: event.rx_time,
              data: data,
              fport: event.frame.port,
              dev_addr: dev_addr,
              confirmed: event.frame.confirmed,
              counter: counter,
              battery: battery_level,
              device_margin: device_margin,
              freq: event.freq,
              gws: all_path.map do |rec|
                rec.delete(:gw_param)
                rec[:margin] = snr_margin(event.sf, event.snr)
                rec[:gw_id] = rec[:gw_id].unpack("m").first
                rec
              end,
              sf: params.up.sf,
              bw: params.up.bw,
              adr: event.frame.adr,
              adr_ack_req: event.frame.adr_ack_req,
              encrypted: not(use_apps?),
              mac_commands: rx_mac_commands
            )
          )

          yield(DeviceUpdateEvent.new(dev_eui: dev_eui))

        end

      else
        clear_return_path!
      end

      self

    end

    def derive_up_counter(counter)

      if up_counter

        if counter < (up_counter & 0xffff)
          counter += (up_counter & 0xffff0000) + 0x10000
        else
          counter += (up_counter & 0xffff0000)
        end

      end

      counter

    end

    # when more than one gateway has sent the message, you need
    # to choose which to send the reply to (if there even is one)
    def select_return_path!(time_now)

      time_now = time_now.to_f

      path = @redis.smembers(rk_return_path(name)).map{|path|JSON.from_json(path)}

      clear_return_path!

      if path.size > 1

        # 1. ensure we only select from recent records
        # 2. sort by ascending SNR (or RSSI when SNR above threshold or equal)
        # 3. remove duplicates by gateway (this should ensure cross-talk ghosting is eliminated)
        #
        path.
        keep_if{|rec|rec[:time] >= time_now}.
        sort! do |a,b|

          a_snr = a[:snr]
          b_snr = b[:snr]

          if (a_snr == b_snr) or ((a_snr > SNR_THRESHOLD) and (b_snr > SNR_THRESHOLD))
            -(a[:rssi] <=> b[:rssi])
          else
            -(a_snr <=> b_snr)
          end

        end.
        uniq!{|rec|rec[:gw_id]}

      end

      return path.first, path

    end

    def pop_downlink
      if event = @redis.rpop(rk_downlink(name))
        JSON.from_json(event)
      end
    end

    def first_event?(key, counter)
      current = @redis.get(key)
      (current.nil? or current.to_i < counter) and (@redis.getset(key, counter) == current)
    end

  end

end
