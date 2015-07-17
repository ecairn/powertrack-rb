module PowerTrack
  class BasePowerTrackError < StandardError
    attr_reader :status, :body
    def initialize(status, msg, body=nil)
      _msg = "#{status}"
      msg ||= body
      _msg += ": #{msg}" if msg
      super(_msg)
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
      if PredefinedStatusPowerTrackError::STATUS_TO_ERROR_CLASS.key?(status)
        PredefinedStatusPowerTrackError::STATUS_TO_ERROR_CLASS[status].new(message, body)
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
    STATUS_TO_ERROR_CLASS = Hash[
      self.descendants.map { |desc| [ desc.new(nil, nil).status, desc ] }.flatten ]
  end

  class BadRequestError < PredefinedStatusPowerTrackError
    def initialize(message, body)
      super(400, message, body)
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
