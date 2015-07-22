# TODO: use BufferedTokenizer from EventMachine ?
module PowerTrack
  class DataBuffer

    SPLIT_PATTERN = /\r\n/
    MESSAGE_PATTERN = /^([^\r]*)\r\n/m

    def initialize
      @buffer = ""
    end

    def process(chunk, &block)
      @buffer.concat(chunk)
      @buffer.gsub!(MESSAGE_PATTERN) do |match|
        yield($1.to_s) if block_given?
        # erase the message
        ''
      end
    end

    def size
      @buffer.size
    end
  end
end
