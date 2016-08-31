require 'eventmachine'
require 'em-http-request'
require 'multi_json'
require 'void_logger'

require 'powertrack/errors'
require 'powertrack/streaming/api'
require 'powertrack/streaming/data_buffer'
require 'powertrack/streaming/retrier'

module PowerTrack
  # A PowerTrack stream to be used for both updating the rules and collecting
  # new messages.
  class Stream
    # Includes the PowerTrack Stream API
    include PowerTrack::API
    # Includes a logger, void by default
    include VoidLogger::LoggerMixin

    # The format of the URLs to connect to the various stream services
    FEATURE_URL_FORMAT = {
      # [ hostname, account, source, mode, label, feature ]
      v1: "https://%s.gnip.com/accounts/%s/publishers/%s/%s/track/%s%s.json".freeze,
      # [ hostname, feature, account, source, label, sub-feature ]
      v2: "https://gnip-%s.twitter.com/%s/powertrack/accounts/%s/publishers/%s/%s%s.json".freeze
    }.freeze

    # The default timeout on a connection to PowerTrack. Can be overriden per call.
    DEFAULT_CONNECTION_TIMEOUT = 30

    # The default timeout for inactivity on a connection to PowerTrack. Can be
    # overriden per call.
    DEFAULT_INACTIVITY_TIMEOUT = 50

    # The default options for using the stream.
    DEFAULT_STREAM_OPTIONS = {
      # enable PowerTrack v2 API (using v1 by default)
      v2: false,
      # override the default connection timeout
      connect_timeout: DEFAULT_CONNECTION_TIMEOUT,
      # override the default inactivity timeout
      inactivity_timeout: DEFAULT_INACTIVITY_TIMEOUT,
      # use a client id if you want to leverage the Backfill feature in v1
      client_id: nil,
      # enable the replay mode to get activities over the last 5 days
      # see http://support.gnip.com/apis/replay/api_reference.html
      replay: false
    }.freeze

    DEFAULT_OK_RESPONSE_STATUS = 200

    # The patterns used to identify the various types of message received from GNIP
    # everything else is an activity
    HEARTBEAT_MESSAGE_PATTERN = /\A\s*\z/.freeze
    SYSTEM_MESSAGE_PATTERN = /\A\s*\{\s*"(info|warn|error)":/mi.freeze

    # The format used to send UTC timestamps in Replay mode
    REPLAY_TIMESTAMP_FORMAT = '%Y%m%d%H%M'.freeze

    attr_reader :username, :account_name, :data_source, :label

    def initialize(username, password, account_name, data_source, label, options=nil)
      @username = username
      @password = password
      @account_name = account_name
      @data_source = data_source
      @label = label
      @options = DEFAULT_STREAM_OPTIONS.merge(options || {})
      @replay = !!@options[:replay]
      @client_id = @options[:client_id]
      @stream_mode = @replay ? 'replay' : 'streams'

      # force v1 if Replay activated
      @v2 = !@replay && !!@options[:v2]
    end

    # Adds many rules to your PowerTrack stream’s ruleset.
    #
    # <tt>POST /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#AddRules
    def add_rules(*rules)
      # flatten the rules in case it was provided as an array
      make_rules_request(:post,
        body: MultiJson.encode('rules' => rules.flatten),
        ok: 201)
    end

    # Removes the specified rules from the stream.
    #
    # <tt>DELETE /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#DeleteRules
    def delete_rules(*rules)
      # v2 does not use DELETE anymore
      delete_verb = @v2 ? :post : :delete
      # flatten the rules in case it was provided as an array
      delete_options = { body: MultiJson.encode('rules' => rules.flatten) }
      # v2 uses a query parameter
      delete_options[:query] = { '_method' => 'delete' } if @v2

      make_rules_request(delete_verb, delete_options)
    end

    DEFAULT_LIST_RULES_OPTIONS = {
      compressed: true,
      objectify: true
    }.freeze

    # Retrieves all existing rules for a stream.
    #
    # Returns an array of PowerTrack::Rule objects when the response permits so.
    #
    # <tt>GET /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#ListRules
    def list_rules(options=nil)
      options = DEFAULT_LIST_RULES_OPTIONS.merge(options || {})
      res = make_rules_request(:get, headers: gzip_compressed_header(options[:compressed]))

      # return Rule objects when required and feasible/appropriate
      if options[:objectify] &&
         res.is_a?(Hash) &&
         (rules = res['rules']).is_a?(Array) &&
         rules.all? { |rule| rule.is_a?(Hash) && rule.key?('value') }
        rules.map do |rule|
          PowerTrack::Rule.new(rule['value'], tag: rule['tag'], id: rule['id'])
        end
      else
        res
      end
    end

    DEFAULT_TRACK_OPTIONS = {
      # receive GZip-compressed payloads ?
      compressed: true,
      # max number of retries after a disconnection
      max_retries: 2,
      # advanced options to configure exponential backoff used for retries
      backoff: nil,
      # max number of seconds to wait for last message handlers to complete
      stop_timeout: 10,
      # pass message in raw form (JSON formatted string) instead of JSON-decoded
      # Ruby objects to message handlers
      raw: false,
      # the starting date from which the activities will be recovered (replay mode only)
      from: nil,
      # the ending date to which the activities will be recovered (replay mode only)
      to: nil,
      # specify a number of minutes to leverage the Backfill feature (v2 only)
      backfill_minutes: nil,
      # called for each message received, except heartbeats
      on_message: nil,
      # called for each activity received
      on_activity: nil,
      # called for each system message received
      on_system: nil,
      # called for each heartbeat received
      on_heartbeat: nil,
      # called periodically to detect if the tracked has to be closed
      close_now: nil
    }.freeze

    # Establishes a persistent connection to the PowerTrack data stream,
    # through which the social data will be delivered.
    #
    # Manages reconnections when being disconnected.
    #
    # <tt>GET /track/:stream</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#Stream
    def track(options=nil)
      options = DEFAULT_TRACK_OPTIONS.merge(options || {})
      retrier = PowerTrack::Retrier.new(options[:max_retries])
      handle_api_response(*retrier.retry { track_once(options, retrier) })
    end

    private

    # Returns the URL of the stream for a given feature.
    def feature_url(hostname, feature=nil, sub_feature=nil)
      _url = nil
      if @v2
        feature ||= hostname
        sub_feature = sub_feature ? "/#{sub_feature}" : ''
        _url = FEATURE_URL_FORMAT[:v2] %
                [ hostname,
                  feature,
                  @account_name,
                  @data_source,
                  @label,
                  sub_feature ]
      else
        feature = feature ? "/#{feature}" : ''
        _url = FEATURE_URL_FORMAT[:v1] %
                [ hostname,
                  @account_name,
                  @data_source,
                  @stream_mode,
                  @label,
                  feature ]

        _url += "?client=#{@client_id}" if @client_id
      end

      _url
    end

    # Returns the HTTP header that turns on GZip-based compression if required.
    # Each call returns a new hash which can be safely modified by the caller.
    def gzip_compressed_header(compressed)
      compressed ? { 'accept-encoding' => 'gzip, compressed' } : {}
    end

    # Returns the authorization header to join to the HTTP request.
    def auth_header
      { 'authorization' => [ @username, @password ] }
    end

    # Returns the HTTP headers common to each valid PowerTrack connection.
    # Each call returns a new hash which can be safely modified by the caller.
    def connection_headers
      { connect_timeout: @options[:connect_timeout],
        inactivity_timeout: @options[:inactivity_timeout] }
    end

    # Opens a new connection to GNIP PowerTrack.
    def connect(hostname, feature=nil, sub_feature=nil)
      url = feature_url(hostname, feature, sub_feature)
      logger.debug("Connecting to '#{url}' with headers #{connection_headers}...")
      EventMachine::HttpRequest.new(url, connection_headers)
    end

    # Returns the HTTP headers common to each valid PowerTrack request.
    # Each call returns a new hash which can be safely modified by the caller.
    def common_req_headers
      { 'accept' => 'application/json',
        'content-type' => 'application/json; charset=utf-8',
        :redirects => 3 }.merge(auth_header)
    end

    # Returns the HTTP headers common to each valid /rules request.
    # Each call returns a new hash which can be safely modified by the caller.
    def rules_req_headers
      common_req_headers
    end

    # Parses a JSON-formatted body received as the response of a PowerTrack API
    # request.
    #
    # Returns nil when the body is empty, the Ruby object decoded from the
    # JSON-formatted body otherwise.
    #
    # If the parsing fails, returns the value returned by the given block which
    # is called with the textual body as a single argument. If no block id,
    # return the textual body initially received.
    def parse_json_body(body, &block)
      body = (body || '').strip
      begin
        body == '' ? nil : MultiJson.load(body)
      rescue
        if block_given?
          yield($!)
        else
          body
        end
      end
    end

    # Returns an appropriate return value or exception according to the response
    # obtained on an API request.
    def handle_api_response(status, error, body, ok=DEFAULT_OK_RESPONSE_STATUS)
      case status
      when nil
        # connection issue
        raise PowerTrack::ConnectionError.new(error)
      when ok
        # successful call: return the body unless there isn't any
        return nil if body.nil?

        parse_json_body(body) do |exception|
          # invalid JSON response
          raise PowerTrack::InvalidResponseError.new(ok, exception.message, body)
        end
      else
        # specified response status
        raise PowerTrack::WithStatusPowerTrackError.build(status, error, parse_json_body(body))
      end
    end

    DEFAULT_RULES_REQUEST_OPTIONS = {
      ok: DEFAULT_OK_RESPONSE_STATUS,
      headers: {},
      query: {},
      body: nil
    }.freeze

    # Makes a rules-related request with a specific HTTP verb and a few options.
    # Returns the response if successful or an exception if the request failed.
    def make_rules_request(verb, options=nil)
      options = DEFAULT_RULES_REQUEST_OPTIONS.merge(options || {})
      resp_status = nil
      resp_error = nil
      resp_body = nil

      EM.run do
        con = connect('api', 'rules')
        http = con.setup_request(verb,
                 head: rules_req_headers.merge(options[:headers]),
                 query: options[:query],
                 body: options[:body])

        http.errback do
          resp_error = http.error
          EM.stop
        end

        http.callback do
          resp_status = http.response_header.status
          resp_error = http.error
          resp_body = http.response
          EM.stop
        end
      end

      handle_api_response(resp_status, resp_error, resp_body, options[:ok])
    end

    # Returns the type of message received on the stream, together with a
    # level indicator in case of a system message, nil otherwise.
    def message_type(message)
      case message
      when HEARTBEAT_MESSAGE_PATTERN then [ :heartbeat, nil ]
      when SYSTEM_MESSAGE_PATTERN then [ :system, $1.downcase.to_sym ]
      else
        [ :activity, nil ]
      end
    end

    # Returns the HTTP headers for each valid /track request.
    # Each call returns a new hash which can be safely modified by the caller.
    def track_req_headers(compressed)
      common_req_headers.merge('connection' => 'keep-alive')
                        .merge(gzip_compressed_header(compressed))
    end

    # Connects to the /track endpoint.
    def track_once(options, retrier)
      logger.info "Starting tracker for retry ##{retrier.retries}..."
      backfill_minutes = options[:backfill_minutes]
      stop_timeout = options[:stop_timeout]
      on_heartbeat = options[:on_heartbeat]
      on_message = options[:on_message]
      on_activity = options[:on_activity]
      on_system = options[:on_system]
      close_now = options[:close_now] || lambda { false }

      buffer = PowerTrack::DataBuffer.new
      closed = false
      disconnected = false
      resp_status = DEFAULT_OK_RESPONSE_STATUS
      resp_error = nil
      resp_body = nil

      EM.run do
        logger.info "Starting the reactor..."
        con = connect('stream')
        get_opts = {
          head: track_req_headers(options[:compressed]),
          query: {}
        }

        # add a timeframe in replay mode
        if @replay
          now = Time.now
          # start 1 hour ago by default
          from = options[:from] || (now - 60*60)
          # stop 30 minutes ago by default
          to = options[:to] || (now - 30*60)

          get_opts[:query].merge!({
            'fromDate' => from.new_offset(0).strftime(REPLAY_TIMESTAMP_FORMAT),
            'toDate' => to.new_offset(0).strftime(REPLAY_TIMESTAMP_FORMAT)
          })

          logger.info "Replay mode enabled from '#{from}' to '#{to}'"
        end

        if @v2 && backfill_minutes
          get_opts[:query]['backfillMinutes'] = backfill_minutes
        end

        http = con.get(get_opts)

        # polls to see if the connection should be closed
        close_watcher = EM.add_periodic_timer(1) do
          # exit if required
          if close_now.call
            logger.info "Time to close the tracker"
            closed = true
            close_watcher.cancel
            con.close
          end
        end

        # simulate periodic disconnections
        if options[:fake_disconnections]
           EM.add_timer(rand(options[:fake_disconnections])) do
             con.close
           end
        end

        http.stream do |chunk|
          # ignore data if already disconnected, thus avoiding synchronizing the
          # buffer. Nevertheless, this should never happen...
          # TODO: log a warning if it happens

          if disconnected
            logger.warn "Message received while already disconnected"
            next
          end

          # process the chunk
          buffer.process(chunk) do |raw|
            logger.debug "New message received"

            # get the message type and its (optional) level
            m_type, m_level = message_type(raw)

            # reset retries when some (valid) data are received but not in replay
            # mode where we don't want to retry on the same timeframe again and
            # again when GNIP periodically fails
            if !@replay && retrier.retrying? && m_level != :error
              logger.info "Resetting retries..."
              retrier.reset!
            end

            EM.defer do
              # select the right message handler(s) according to the message type
              if m_type == :heartbeat
                on_heartbeat.call if on_heartbeat
              else
                # JSON decoding if required
                message = options[:raw] ? raw : MultiJson.decode(raw)

                on_message.call(message) if on_message

                case m_type
                when :system then on_system.call(message) if on_system
                when :activity then on_activity.call(message) if on_activity
                end
              end

              # TODO: manage exceptions at this level
            end
          end
        end

        # reconnection on error
        reconnect_cb = lambda do |http_client|
          logger.info "Disconnected after #{retrier.retries} retries"
          disconnected = true

          resp_status = http_client.response_header.status

          # stop the stream if required so or the replay is simply over
          if closed || (@replay && resp_status == DEFAULT_OK_RESPONSE_STATUS)
            # close immediately if required
            wait_til_defers_finish_and_stop(stop_timeout)
            # tell the retrier the tracking is over
            retrier.stop
          else
            # cancel the periodic close watcher
            close_watcher.cancel

            resp_status ||= DEFAULT_OK_RESPONSE_STATUS
            resp_error = http_client.error
            resp_body = http_client.response

            wait_til_defers_finish_and_stop(stop_timeout)
          end
        end

        http.callback(&reconnect_cb)
        http.errback(&reconnect_cb)
      end

      [ resp_status, resp_error, resp_body ]
    end

    # Waits for all the deferrable threads to complete, then stops the reactor.
    def wait_til_defers_finish_and_stop(timeout)
      # wait for defers to terminate but no more than timeout...
      start = Time.now
      defers_waiter = EM.add_periodic_timer(0.2) do
        logger.info "Waiting for defers..."
        if EM.defers_finished? || (Time.now - start) > timeout
          defers_waiter.cancel
        end
      end
    ensure
      logger.info "Stopping the reactor..."
      EM.stop
    end
  end
end
