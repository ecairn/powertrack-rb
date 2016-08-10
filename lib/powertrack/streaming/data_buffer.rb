module PowerTrack
  # A buffer of data received from PowerTrack. Useful for managing the sequential
  # chunk of bytes sent of the stream by GNIP and slice them into well-formatted
  # messages.
  class DataBuffer

    # The pattern used by GNIP PowerTrack to delimitate a single message.
    MESSAGE_PATTERN = /^([^\r]*)\r\n/m.freeze

    # Builds a new data buffer.
    def initialize
      @buffer = ''
    end

    # Add a chunk of bytes to the buffer and pass the new message(s) extracted
    # to the block provided.
    def process(chunk, &block)
      @buffer.concat(chunk)
      @buffer.gsub!(MESSAGE_PATTERN) do |match|
        yield($1.to_s) if block_given?
        # erase the message
        ''
      end
    end

    # The current size of the buffer.
    def size
      @buffer.size
    end

    # Resets the buffer, therefore losing any bytes received from PowerTrack.
    def reset!
      @buffer = ''
    end
  end
end
