require 'logger'

module Flora

  LOG_FORMATTER = Proc.new do |severity, datetime, progname, msg|
    "#{severity.ljust(5)} [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{msg}\n"
  end

  module LoggerMethods
  
    NULL_LOGGER = Logger.new(IO::NULL)
    NULL_LOGGER.level = Logger::WARN
  
    def log_info(&block)        
      @logger.info(log_header, &block)
    end
    
    def log_error(&block)        
      @logger.debug(log_header, &block)
    end
    
    def log_debug(&block)        
      @logger.debug(log_header, &block)
    end

    def log_header
      self.class.name
    end
    
  end

end
