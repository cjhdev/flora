module Flora

  module RedisKeys
  
    EUI         = 'EUI:'.freeze
    DEV_ADDR    = 'ADDR:'.freeze
    RETURN      = 'RP:'.freeze
    DOWNLINK    = 'DL:'.freeze
    FIRST_JOIN  = 'FIRST_JOIN:'.freeze
    FIRST_DATA  = 'FIRST_DATA:'.freeze
    NWK_COUNTER = 'NWK_COUNTER:'.freeze
    APP_COUNTER = 'APP_COUNTER:'.freeze
    UP_HISTORY  = 'UP_HIST:'.freeze
    ADR_SETTING = 'ADR_SETTING:'.freeze
    GW_DL_ADDR = 'GW_DL_ADDR:'.freeze
    
    GW_LOOKUP   = 'GW_LOOKUP:'.freeze
    GW_STATUS   = 'GW_STATUS:'.freeze
    GW_DOWNLINK = 'GW_DOWNLINK:'.freeze
  
    def rk_eui(name)
      EUI + name
    end
    
    def rk_dev_addr(dev_addr)
      DEV_ADDR + dev_addr.to_s
    end
    
    def rk_nwk_counter(name)
      NWK_COUNTER + name
    end
    
    def rk_app_counter(name)
      APP_COUNTER + name
    end
    
    def rk_downlink(name)
      DOWNLINK + name
    end
    
    def rk_return_path(name)
      RETURN + name
    end
    
    def rk_first_join(name)
      FIRST_JOIN + name
    end
    
    def rk_first_data(name)
      FIRST_DATA + name
    end
    
    def rk_uplink_history(name)
      UP_HISTORY + name
    end
    
    def rk_adr_setting(name)
      ADR_SETTING + name
    end
    
    def gw_dl_addr(eui)
      GW_DL_ADDR + eui
    end
    
    def rk_gw_lookup(eui)
      GW_LOOKUP + eui
    end
    
    def rk_gw_status(eui)
      GW_GW_STATUS + eui
    end
    
    def rk_gw_downlink(eui)
      GW_GW_DOWNLINK + eui
    end
    
  end

end
