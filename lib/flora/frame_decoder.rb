module Flora

  class FrameDecoder

    include LoggerMethods

    def initialize(**opts)
      @logger = opts[:logger]||NULL_LOGGER
      @lookup = Frame.subs.select{|f|f.type}.map{|f|[f.tag, f]}.to_h
    end

    def decode(input)

      s = InputCodec.new(input)
      cls = @lookup[s.get_u8]
      cls.decode(s) if cls

    end

    def mhdr_to_cls(tag)
      @lookup[tag]
    end

  end

end
