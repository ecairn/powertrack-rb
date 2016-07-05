require 'exponential_backoff'

module PowerTrack
  # A utility class that manges an exponential backoff retry pattern.
  # Additionally, this king of retrier can be reset or stopped by the code being
  # retried.
  class Retrier
    attr_reader :retries, :max_retries

    # the default minimum number of seconds b/w 2 attempts
    DEFAULT_MIN_INTERVAL = 1.0
    # the default maximum number of seconds to wait b/w 2 attempts
    DEFAULT_MAX_ELAPSED_TIME = 30.0
    # the default interval multiplier
    DEFAULT_INTERVAL_MULTIPLIER = 1.5
    # the default randomize factor
    DEFAULT_RANDOMIZE_FACTOR = 0.25

    # default options used by a retrier unless others specified at initialization
    DEFAULT_OPTIONS = {
      min_interval: DEFAULT_MIN_INTERVAL,
      max_elapsed_time: DEFAULT_MAX_ELAPSED_TIME,
      multiplier: DEFAULT_INTERVAL_MULTIPLIER,
      randomize_factor: DEFAULT_RANDOMIZE_FACTOR
    }

    # Builds a retrier that will retry a maximum retries number of times.
    def initialize(max_retries, options=nil)
      options = DEFAULT_OPTIONS.merge(options || {})

      @max_retries = max_retries
      @retries = 0
      @continue = true
      @backoff = ExponentialBackoff.new(options[:min_interval], options[:max_elapsed_time])
      @backoff.multiplier = options[:multiplier]
      @backoff.randomize_factor = options[:randomize_factor]
    end

    # Resets the retrier.
    def reset!
      @retries = 0
      @backoff.clear
    end

    # Returns true if the retrier is currently retrying.
    def retrying?
      @retries != 0
    end

    # Stops retrying even after a reset. To be used from the code being retried.
    def stop
      @continue = false
    end

    # Retries the block of code provided according to the configuration of the
    # retrier.
    def retry(&block)
      # TODO: manage exceptions
      while @continue && @retries <= @max_retries
        res = yield
        if @continue
          @retries += 1
          sleep(@backoff.next_interval)
        end
      end

      res
    end
  end
end
