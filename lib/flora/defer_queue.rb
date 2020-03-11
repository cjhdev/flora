module Flora

  class DeferQueue

    include LoggerMethods

    def initialize(**opts)
      
      @logger = opts[:logger]||NULL_LOGGER
      
      @worker_queue_depth = opts[:event_queue_depth]||100
      @num_workers = opts[:num_event_workers]||5
      
      @mutex = Mutex.new
      @update = ConditionVariable.new          
      @event = Struct.new(:timeout, :block)
      @queue = []
      
      @worker_queue = TimeoutQueue.new(max: @worker_queue_depth)      
      @worker = []
      
      @timer_thread = nil
      
      @running = false
      
    end

    def start
      if not @running
        @worker_queue = TimeoutQueue.new(max: @worker_queue_depth)
        @worker = Array.new(@num_workers) do
          Thread.new do
            begin              
              loop do
                action = @worker_queue.pop
                begin
                  action.call
                rescue => e
                  log_debug{"caught #{e}: #{e.backtrace.join("\n")}"}
                end
              end
            rescue ClosedQueueError
            end
          end
        end
        @timer_thread = Thread.new do
          begin
            timer_task
          rescue Interrupt
          end
        end
        @running = true
      end
      self
    end
    
    def stop
      if @running
        @timer_thread.raise Interrupt
        @worker_queue.close
        @worker.each(&:join)
        @worker.clear
        @running = false
      end
      self
    end

    def on_timeout(interval, &block)
    
      interval = interval.to_f
    
      event = nil
      
      with_mutex do                
      
        event = @event.new(Time.now + interval, block)
      
        if @queue.empty?
          
          @queue.push(event)
        
        else                
          
          inserted = false
        
          @queue.reverse_each.with_index do |existing, index|
          
            if event.timeout >= existing.timeout
              
              @queue.insert(@queue.size - index, event)
              inserted = true
              break
            
            end
          end
            
          @queue.push(event) unless inserted
              
        end                        
        
        @update.signal         
        
      end
      
      event  
    
    end
    
    def cancel(event)
      with_mutex do
        @queue.delete_if { |e| e == event }
      end
      self
    end
      
    def clear    
      with_mutex do
        @queue.clear
      end
      self
    end

    def timer_task
      
      loop do
              
        expired = nil
        
        with_mutex do         
        
          time_now = Time.now
          
          if not(@queue.empty?) and @queue.first.timeout <= time_now
            
            expired = @queue.shift
          
          else
        
            loop do
            
              time_now = Time.now
            
              # break if there are expired timeouts
              break unless @queue.empty? or (time_now < @queue.first.timeout)
              
              if @queue.empty?
          
                @update.wait(@mutex)
              
              else
              
                @update.wait(@mutex, @queue.first.timeout - time_now)
                
              end
              
            end
            
          end
        
        end
        
        if expired
          begin
            @worker_queue.push(expired.block)
          rescue ClosedQueueError
          end
        end
          
      end
    end

    def with_mutex
      @mutex.synchronize do
        yield
      end
    end
    
    private :with_mutex

  end
  
end
