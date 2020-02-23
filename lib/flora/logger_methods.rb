module Flora

  LOG_FORMATTER = Proc.new do |severity, datetime, progname, msg|
    "#{severity.ljust(5)} [#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{msg}\n"
  end

  module LoggerMethods
  
    def log_info(msg)        
      @logger.info { "#{log_header if self.respond_to? :log_header}#{msg}" } if @logger
    end
    
    def log_error(msg)
      @logger.error { "#{log_header if self.respond_to? :log_header}#{msg}" } if @logger    
    end
    
    def log_debug(msg)
      @logger.debug { "#{log_header if self.respond_to? :log_header}#{msg}" } if @logger
    end

    def log_header
      "#{self.class.name.split("::").last}: "
    end
    
  end

end
