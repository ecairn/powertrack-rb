module PowerTrack
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

   class NoStatusPowerTrackError < BasePowerTrackError
    def initialize(message, body)
      super(nil, message, body)
    end
  end

  class ConnectionError < NoStatusPowerTrackError
    def initialize(message)
      super(message, nil)
    end
  end

  class WithStatusPowerTrackError < BasePowerTrackError
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

  class InvalidResponseError < WithStatusPowerTrackError
  end

  class UnknownStatusError < WithStatusPowerTrackError
  end

  class PredefinedStatusPowerTrackError < WithStatusPowerTrackError
  end

  class BadRequestError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(400, message, body)
    end
  end

  class NotAcceptableError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(406, message, body)
    end
  end

  class UnauthorizedError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(401, message, body)
    end
  end

  class UnprocessableEntityError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(422, message, body)
    end
  end

  class RateLimitedError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(429, message, body)
    end
  end

  class ServiceUnavailableError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(503, message, body)
    end
  end
end
