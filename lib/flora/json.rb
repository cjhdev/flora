module Flora

  module JSON
    
    JSON_OPTS={}
    
    begin
      
      # use OJ if it's available
      require 'oj'
      
      def self.to_json(input)
        Oj.dump(input, mode: :compat)        
      end
      
      def self.from_json(input, opts=JSON_OPTS)
        begin        
          if opts[:symbols] == false
            Oj.load(input, max_nesting: 3)
          else
            Oj.load(input, symbol_keys: true, max_nesting: 3)            
          end          
        rescue => e
          raise JSONError.new(e)
        end
      end  
      
    rescue LoadError
    
      require 'json'
  
      def self.to_json(input)
        input.to_json
      end
      
      def self.from_json(input, opts=JSON_OPTS)
        begin
          if opts[:symbols] == false
            ::JSON.parse(input, max_nesting: 3)
          else
            ::JSON.parse(input, symbolize_names: true, max_nesting: 3)            
          end
        rescue => e
          raise JSONError.new(e)
        end
      end
    
    end
    
  end

end
