require_relative 'environment'

# create Sinatra app
class App

  helpers Helpers

  get '/' do
  
    redirect "/devices"
    
  end
  
  get '/devices' do
    
    devices = Device.order(:created_at).all    
    events = LwEvent.eager(:device).eager(:lw_gateway_metas).reverse(:rx_time).limit(100).to_a
    
    haml(:devices, locals: {devices: devices, events: events})
    
  end
  
  get '/devices/:eui' do
  
    device = Device.first(dev_eui: params[:eui])
    
    halt 404 unless device
    
    stats = {
      activation: LwEvent.where(device_id: device.id, type: 'LwEventActivation').count,
      data: LwEvent.where(device_id: device.id, type: 'LwEventData').count    
    }
    
    events = LwEvent.where(device_id: device.id).eager(:device).eager(:lw_gateway_metas).reverse(:rx_time).limit(100).to_a
    
    haml(:device, locals: {device: device, events: events, stats: stats})
    
  end

  get '/asset/chartkick.js' do
    send_file(find_asset(request.path.split("/").last))
  end

  get '/asset/Chart.bundle.js' do
    send_file(find_asset(request.path.split("/").last))
  end

end

# create Flora instance
server = Flora::Server.create do

  redis(Redis.new)

  gateway_connector(:semtech, port: SETTINGS[:gateway_port], host: SETTINGS[:gateway_host])

  logger(LOGGER)    
  
  handle_gw_meta = Proc.new do |ev, ev_model|
  
    ev.gws.each do |gw_meta|
      
      LwGatewayMeta.create do |m|
      
        m.gw_eui = [gw_meta[:id]].pack("m0")
        
        m.snr = gw_meta[:snr]
        m.rssi = gw_meta[:rssi]
        m.margin = gw_meta[:margin]
        
        m.lw_event_id = ev_model.id
      
      end
      
    end
  
  end
  
  on_event do |ev, server|
  
    #pp ev
      
    case ev
    when Flora::ActivationEvent
      
      dev_eui = [ev.dev_eui].pack("m0")
  
      if device = Device.first(dev_eui: dev_eui)

        DB.transaction do
        
          ev_model = LwEventActivation.create do |m|
          
            m.rx_time = ev.rx_time
            m.freq = ev.freq
            m.sf = ev.sf
            m.bw = ev.bw
            
            m.dev_nonce = ev.dev_nonce
            m.join_nonce = ev.join_nonce
            
            m.dev_eui = dev_eui
            m.join_eui = [ev.join_eui].pack("m0")
            
            m.device_id = device.id
            
          end
          
          handle_gw_meta.call(ev, ev_model)
          
        end
      
      end
      
    when Flora::DataUpEvent
      
      if device = Device.first(dev_eui: [ev.dev_eui].pack("m0"))
      
        DB.transaction do
        
          ev_model = LwEventData.create do |m|
          
            m.rx_time = ev.rx_time
            m.freq = ev.freq
            m.sf = ev.sf
            m.bw = ev.bw
            
            m.fport = ev.fport
            m.data = [ev.data].pack("m0") if ev.data
            
            m.counter = ev.counter
            m.battery = ev.battery
            m.device_margin = ev.device_margin
            m.confirmed = ev.confirmed
            
            m.dev_addr = ev.dev_addr
            
            m.device_id = device.id
            
            m.encrypted = ev.encrypted
            
            m.adr = ev.adr
            m.adr_ack_req = ev.adr_ack_req
            
          end

          handle_gw_meta.call(ev, ev_model)

        end
        
      end  
      
    when Flora::DeviceUpdateEvent        
      
      dev_eui = [ev.dev_eui].pack("m0")
  
      exported = server.export_device(ev.dev_eui)
    
      if device = Device.first(dev_eui: dev_eui)
      
        device.update(exported: exported.to_json)
        
      end
      
    end
  
  end
  
end

# warm cache
Device.all.each do |device|
  
  exported = JSON.parse(device.exported) if device.exported
  
  if exported
  
    begin
    
      server.restore_device(exported)
      
    rescue => ex
    
      LOGGER.error "could not restore from exported (so creating fresh device)"
      
      server.create_device([device.dev_eui].unpack("m"))
      device.update(exported: nil)
      
    end
  
  else
    
    server.create_device(
      dev_eui: device.dev_eui.unpack("m").first,
      dev_addr: device.dev_addr,
      nwk_key: device.nwk_key.unpack("m").first,
      app_key: device.app_key ? device.app_key.unpack("m").first : nil,
      channel_plan: device.channel_plan,
      minor: device.minor    
    )
    
  end
  
end

server.start

App.run!

server.stop
