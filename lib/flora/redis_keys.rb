module Flora

  module RedisKeys
  
    def rk_eui(name)
      Prefix::EUI + name
    end
    
    def rk_dev_addr(dev_addr)
      Prefix::DEV_ADDR + dev_addr.to_s
    end
    
    def rk_nwk_counter(name)
      Prefix::NWK_COUNTER + name
    end
    
    def rk_app_counter(name)
      Prefix::APP_COUNTER + name
    end
    
    def rk_downlink(name)
      Prefix::DOWNLINK + name
    end
    
    def rk_return_path(name)
      Prefix::RETURN + name
    end
    
    def rk_first_join(name)
      Prefix::FIRST_JOIN + name
    end
    
    def rk_first_data(name)
      Prefix::FIRST_DATA + name
    end
    
    def rk_uplink_history(name)
      Prefix::UP_HISTORY + name
    end
    
    def rk_adr_setting(name)
      Prefix::ADR_SETTING + name
    end
    
    def gw_dl_addr(eui)
      Prefix::GW_DL_ADDR + eui
    end
    
  end

end
