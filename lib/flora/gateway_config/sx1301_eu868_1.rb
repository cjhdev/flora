Flora::SX1301Config.create(
  File.basename(__FILE__, ".rb"),
  region: :EU_863_870,
  tx_freq_range: [863000000, 870000000],
  config: [
    {
      radio_0: {
        enable: true,
        freq: 867500000
      },
      radio_1: {
        enable: true,
        freq: 868500000
      },
      chan_multiSF_0: {
        enable: true,
        radio: 1,
        if: -400000
      },
      chan_multiSF_1: {
        enable: true,
        radio: 1,
        if: -200000
      },
      chan_multiSF_2: {
        enable: true,
        radio: 1,
        if: 0
      },
      chan_multiSF_3: {
        enable: true,
        radio: 0,
        if: -400000
      },
      chan_multiSF_4: {
        enable: true,
        radio: 0,
        if: -200000
      },
      chan_multiSF_5: {
        enable: true,
        radio: 0,
        if: 0
      },
      chan_multiSF_6: {
        enable: true,
        radio: 0,
        if: 200000
      },
      chan_multiSF_7: {
        enable: true,
        radio: 0,
        if: 400000
      },
      chan_Lora_std: {
        enable: false,
        radio: 0
      },
      chan_FSK: {
        enable: false,
        radio: 0
      }
    }    
  ] 
)
