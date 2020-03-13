module Flora

  GatewayUpEvent = Struct.new(:rx_time, :gw_id, :freq, :sf, :bw, :frame, :data, :snr, :rssi, :gw_param, :gw_channels, keyword_init: true)
  GatewayDownEvent = Struct.new(:gw_id, :gw_param, :data, :dev_eui, :rx_delay, :rx_param, :gw_eui, keyword_init: true)
  
  # Sent to application to indicate device activation
  #
  # @attr [String]  dev_eui     byte string 
  # @attr [String]  join_eui    byte string
  # @attr [Time]    rx_time     time frame was received
  # @attr [Integer] dev_addr    device address
  # @attr [Integer] dev_nonce   device nonce
  # @attr [Integer] join_nonce   join nonce
  # @attr [Integer] freq        frequency (Hz)
  # @attr [Integer] bw          bandwidth (Hz)
  # @attr [Integer] sf          spreading factor
  # @attr [Array<Hash>] gws     array of meta data from each gateway that received the message
  #
  # gateway meta data hash:
  #
  # @option gw [String] :gw_id     byte string
  # @option gw [String] :rssi
  # @option gw [String] :snr
  # @option gw [String] :margin
  # 
  ActivationEvent = Struct.new(:dev_eui, :join_eui, :rx_time, :dev_addr, :dev_nonce, :join_nonce, :freq, :gws, :sf, :bw, keyword_init: true)
  
  # Sent to application to pass upstream data
  #
  # @attr [String]  dev_eui             byte string 
  # @attr [String]  join_eui            byte string
  # @attr [Time]    rx_time             time frame was received
  # @attr [Integer] dev_addr            device address
  # @attr [Integer] freq                frequency (Hz)
  # @attr [Integer] bw                  bandwidth (Hz)
  # @attr [Integer] sf                  spreading factor
  # @attr [Array<Hash>] gws             array of meta data from each gateway that received the message
  # @attr [String,nil]  data            byte string
  # @attr [Integer,nil] fport           frame port value    
  # @attr [true,false] confirmed        true if this was a confirmed frame
  # @attr [Integer] counter             counter associated with message
  # @attr [Integer,nil] battery         battery level (from device status MAC command)
  # @attr [Integer,nil] device_margin   SNR margin reported by device (dB) (from device status MAC command)
  # @attr [true,false] adr              true if ADR bit was set
  # @attr [true,false] adr_ack_req      true if device asked for ADR ack
  # @attr [true,false] encrypted        true if data is encrypted with apps key
  # @attr [Array<MacCommand>] mac_commands  parsed MAC command(s)
  #
  # gateway meta data hash:
  #
  # @option gw [String] :gw_id   byte string
  # @option gw [String] :rssi
  # @option gw [String] :snr
  # @option gw [String] :margin
  #   
  DataUpEvent = Struct.new(:dev_eui, :rx_time, :data, :fport, :dev_addr, :confirmed, :counter, :battery, :device_margin, :freq, :gws, :sf, :bw, :adr, :adr_ack_req, :encrypted, :mac_commands, keyword_init: true)
  
  # Sent to application to indicate device record has changed
  #
  # The application can use this event to save the device record by the Server#export_device method
  #
  # @attr [String] dev_eui  byte string
  #
  DeviceUpdateEvent = Struct.new(:dev_eui, keyword_init: true)
  
end
