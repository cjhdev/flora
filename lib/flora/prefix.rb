module Flora

  # prefixes used with Redis keys
  module Prefix
  
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
  
  end
  
end
