# hostname and port settings
SETTINGS = {
  gateway_port: 1700,
  gateway_host: '0.0.0.0',
  app_port: 4567,
  app_host: 'localhost'
}

require 'rubygems'
require 'bundler/setup'

APP_ROOT = Pathname.new(File.expand_path('../', __FILE__))
APP_NAME = APP_ROOT.basename.to_s

Bundler.require

require 'logger'
require 'sinatra/base'
require_relative 'helpers'

LOGGER = Logger.new(STDOUT).tap do |log|
  log.formatter = Flora::LOG_FORMATTER
  log.sev_threshold = Logger::DEBUG
end

class App < Sinatra::Base

  configure do
  
    set :root, APP_ROOT.to_path
    set :server, :puma
    enable :logging
    set :port, SETTINGS[:app_port]
    set :host, SETTINGS[:app_host]
    
  end
  
end

DB = Sequel.sqlite(APP_ROOT.join('db','demo.sqlite3').to_path) unless defined? DB

#DB.loggers << LOGGER
#DB.sql_log_level = :debug

Dir[APP_ROOT.join('models', '*.rb')].each do |f|
  require f
end
