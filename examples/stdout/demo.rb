SETTINGS = {
  gateway_port: 1700,
  gateway_host: '0.0.0.0'
}

require 'rubygems'
require 'bundler/setup'

Bundler.require

require 'logger'
require 'pp'

LOGGER = Logger.new(STDOUT).tap do |log|
  log.formatter = Flora::LOG_FORMATTER
  log.sev_threshold = Logger::DEBUG
end

server = Flora::Server.create do |s|

  redis Redis.new

  gateway_connector :semtech, port: SETTINGS[:gateway_port], host: SETTINGS[:gateway_host]
  
  s.logger(LOGGER)    
  
  on_event do |ev|
    
    # just print upstream events
    pp ev
       
  end
  
end

# add your devices here

server.create_device(
  dev_eui: "\x4C\xFE\x95\x71\x00\xF0\x9C\x3A", 
  dev_addr: 0,
  nwk_key: "\x20\x84\x98\x7E\x78\xC8\x51\xEE\x49\x5E\x1D\x78\x34\x81\xD4\x75",
  channel_plan: "default_eu",
  minor: 0
)

# finally start the server

server.start

begin
  sleep
rescue Interrupt
end

server.stop
