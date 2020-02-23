module Helpers

  def format_time(time)
    time.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  def format_eui(eui)
    eui.unpack("m").first.bytes.map{|b|"%02X"%b}.join
  end
  
  def format_dev_addr(value)
    "%08X" % value
  end
  
  def format_dev_nonce(value)
    "%04X" % value
  end
  
  def format_join_nonce(value)
    "%06X" % value
  end
  
  def convert_eui_from_param(eui)
    eui.unpack("H16").first
  end
  
  def format_sf_and_bw(sf, bw)
    "SF#{sf}BW#{bw/1000}"
  end
  
  def format_device_link(dev_eui)
    "devices/#{dev_eui}"
  end
  
  def format_data(data)
    if data
      bytes = data.unpack("m").first
      bytes.slice(0..8).bytes.map{|b|"%02X"%b}.join.concat((bytes.size > 8) ? "..." : "")
    else
      "-"
    end
  end
  
  def copy_icon
    "<div class=\"download icon\"></div>"
  end
  
  def format_last_seen(last_event)
    
    return "never" if last_event.nil?
    
    time_since = (Time.now - last_event.rx_time).to_i
    
    seconds = time_since % 60
    minutes = time_since / 60 % 60
    hours = time_since / 3600 % 3600
    days = time_since / 86400 % 86400
    
    if days > 0
      
      if (hours % 24) > 0
      
        "#{days} day#{days > 1 ? "s" : ""} and #{hours % 24} hour#{(hours % 24) > 1 ? "s" : ""} ago"
      
      else
      
        "#{days} day#{days > 1 ? "s" : ""} ago"
      
      end
      
    elsif hours > 0
      
      "at least #{hours} hour#{hours > 1 ? "s" : ""} ago"
      
    elsif minutes > 0
    
      "#{minutes} minute#{minutes > 1 ? "s" : ""} ago"
    
    else
    
      "#{seconds} second#{seconds > 1 ? "s" : ""} ago"
    
    end
      
  end
  
  alias_method :format_counter, :format_dev_addr
  
  def format_event_type(type)
    case type
    when 'LwEventActivation'
      'activation'
    when 'LwEventData'
      'data'
    else
      type
    end
  end
  
  def format_chart_time(time)
    time.strftime("%d-%m-%Y %H:%M:%S")    
  end
  
  def find_asset(name)
  
    asset = "../vendor/assets/javascripts/#{name}"
  
    $LOAD_PATH.each do |path|
    
      full_path = File.join(path, asset)
    
      return full_path if File.file?(full_path)
       
    end
    
    nil
    
  end
  
  def margin_chart(events)
    area_chart(events.map{|e|[e.rx_time, e.lw_gateway_metas.first.margin]}, 
      title: "Margin", 
      height: "200px",
      ytitle: "dB",
      library: {
        scales: {
          xAxes: [{
            ticks: {
              display: false
                }
          }]
        }
      }      
    )
  end
    
  def snr_rssi_chart(events)
    line_chart([
        {name: "snr", data: events.map{|e|[e.rx_time, e.lw_gateway_metas.first.snr]}},
        {name: "rssi", data: events.map{|e|[e.rx_time, e.lw_gateway_metas.first.rssi]}}
      ],
      title: "SNR and RSSI",
      height: "400px",
      ytitle: "dB",
      library: {
        scales: {
          xAxes: [{
            ticks: {
              display: false
                }
          }]
        }
      }
    )
  end
  
  def snr_chart(events)
    line_chart(events.map{|e|[e.rx_time, e.lw_gateway_metas.first.snr]}, 
      title: "SNR", 
      height: "200px",
      ytitle: "dB",
      library: {
        scales: {
          xAxes: [{
            ticks: {
              display: false
                }
          }]
        }
      }
    )
  end
  
  def rssi_chart(events)
    line_chart(events.map{|e|[e.rx_time, e.lw_gateway_metas.first.rssi]}, 
      title: "RSSI", 
      height: "200px",
      ytitle: "dB",
      library: {
        scales: {
          xAxes: [{
            ticks: {
              display: false
                }
          }]
        }
      }
    )
  end
    
end
