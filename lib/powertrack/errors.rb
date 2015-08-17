module PowerTrack
  # Base PowerTrack error, capable of wrapping another
  class BasePowerTrackError < StandardError
    attr_reader :status, :body

    def initialize(status, msg, body=nil)
      msg ||= body
      _status = "#{status}".strip
      _msg = "#{msg}".strip
      err = [ _status, _msg ].select { |part| !part.empty? }.join(': ')
      super(err)
      @status = status
      @body = body
    end
  end

  # Base class for PowerTrack errors without a precise status
  class NoStatusPowerTrackError < BasePowerTrackError
    def initialize(message, body)
      super(nil, message, body)
    end
  end

  # An error which is raised when there is a connection issue with the PowerTrack
  # endpoint
  class ConnectionError < NoStatusPowerTrackError
    def initialize(message)
      super(message, nil)
    end
  end

  # Base class for PowerTrack errors with a precise status
  class WithStatusPowerTrackError < BasePowerTrackError
    # Factory method which returns an error instance based on a given status.
    def self.build(status, message, body)
      @@status_to_error_class ||= Hash[*self.descendants.map { |desc|
        [ desc.new(nil, nil).status, desc ] }.flatten ]
      if @@status_to_error_class.key?(status)
        @@status_to_error_class[status].new(message, body)
      else
        # default to unknown status error
        UnknownStatusError.new(status, message, body)
      end
    end
  end

  # An exception which is raised when the response received from PowerTrack is
  # invalid, poorly formatted in most cases.
  class InvalidResponseError < WithStatusPowerTrackError
  end

  # An exception which is raised when PowerTrack returns an unknown HTTP status code.
  class UnknownStatusError < WithStatusPowerTrackError
  end

  # Base class for errors which match a well-defined HTTP status code as
  # documented in the PowerTrack API reference.
  class PredefinedStatusPowerTrackError < WithStatusPowerTrackError
  end

  # Generally relates to poorly formatted JSON, and includes an "Invalid JSON"
  # message in the response.
  class BadRequestError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(400, message, body)
    end
  end

  # HTTP authentication failed due to invalid credentials.
  class UnauthorizedError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(401, message, body)
    end
  end

  # Generally, this occurs where your client fails to properly include the
  # headers to accept gzip encoding from the stream, but can occur in other
  # circumstances as well.
  #
  # Will contain a JSON message similar to "This connection requires
  # compression. To enable compression, send an 'Accept-Encoding: gzip' header
  # in your request and be ready to uncompress the stream as it is read on
  # the client end."
  class NotAcceptableError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(406, message, body)
    end
  end

  class UnprocessableEntityError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(422, message, body)
    end
  end

  # Your app has exceeded the limit on connection requests.
  class RateLimitedError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(429, message, body)
    end
  end

  # Gnip server issue. If no notice about this issue has been posted on
  # status.gnip.com, email support@gnip.com.
  class ServiceUnavailableError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(503, message, body)
    end
  end
end
