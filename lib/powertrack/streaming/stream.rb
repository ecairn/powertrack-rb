require 'eventmachine'
require 'em-http-request'
require 'multi_json'

require 'powertrack/errors'
require 'powertrack/streaming/api'
require 'powertrack/streaming/data_buffer'

module PowerTrack
  class Stream
    include PowerTrack::API

    FEATURE_URL_FORMAT = "https://%s.gnip.com/accounts/%s/publishers/%s/streams/track/%s/%s.json"
    DEFAULT_CONNECTION_TIMEOUT = 30
    DEFAULT_INACTIVITY_TIMEOUT = 50

    DEFAULT_STREAM_OPTIONS = {
      connect_timeout: DEFAULT_CONNECTION_TIMEOUT,
      inactivity_timeout: DEFAULT_INACTIVITY_TIMEOUT,
      # use a client id if you want to leverage the Backfill feature
      client_id: nil
    }

    DEFAULT_OK_RESPONSE_STATUS = 200

    # the patterns used to identify the various types of message received from GNIP
    HEARTBEAT_MESSAGE_PATTERN = /\A\s*\z/
    SYSTEM_MESSAGE_PATTERN = /\A\s*\{\s*"(info|warn|error)":/mi
    ACTIVITY_MESSAGE_PATTERN = /\A\s*\{.*"objectType":/mi

    attr_reader :username, :account_name, :data_source, :label

    def initialize(username, password, account_name, data_source, label, options=nil)
      @username = username
      @password = password
      @account_name = account_name
      @data_source = data_source
      @label = label
      @options = DEFAULT_STREAM_OPTIONS.merge(options || {})
      @client_id = @options[:client_id]
    end

    # Adds many rules to your PowerTrack stream’s ruleset.
    #
    # <pre>POST /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#AddRules
    def add_rules(*rules)
      make_rules_request(:post, body: MultiJson.encode('rules' => rules), ok: 201)
    end

    # Removes the specified rules from the stream.
    #
    # <pre>DELETE /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#DeleteRules
    def delete_rules(*rules)
      make_rules_request(:delete, body: MultiJson.encode('rules' => rules))
    end

    DEFAULT_LIST_RULES_OPTIONS = {
      compressed: true,
      objectify: true
    }

    # Retrieves all existing rules for a stream.
    #
    # Returns an array of PowerTrack::Rule objects when the response permits so.
    #
    # <pre>GET /rules</pre>
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
        rules.map { |rule| PowerTrack::Rule.new(rule['value'], rule['tag']) }
      else
        res
      end
    end

    DEFAULT_TRACK_OPTIONS = {
      compressed: true,
      max_retries: 5,
      stop_timeout: 10,
      raw: false,
      on_message: nil,
      on_activity: nil,
      on_system: nil,
      on_heartbeat: nil,
      close_now: nil,
      monitor: nil
    }

    # Establishes a persistent connection to the PowerTrack data stream,
    # through which the social data will be delivered.
    #
    # <pre>GET /track/:stream</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#Stream
    def track(options=nil)
      options = DEFAULT_TRACK_OPTIONS.merge(options || {})
      buffer = PowerTrack::DataBuffer.new
      res = nil

      EM.run { res = track_and_reconnect(buffer, options) }

      handle_api_response(*res)
    end

    private

    # Returns the URL of the stream for a given feature.
    def feature_url(hostname, feature='')
      _url = FEATURE_URL_FORMAT % [ hostname, @account_name, @data_source, @label, feature ]
      _url += "?client=#{@client_id}" if @client_id

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
    def connect(hostname, feature='')
      url = feature_url(hostname, feature)
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

    # Returns the HTTP headers for each valid /track request.
    # Each call returns a new hash which can be safely modified by the caller.
    def track_req_headers(compressed)
      common_req_headers.merge('connection' => 'keep-alive')
                        .merge(gzip_compressed_header(compressed))
    end

    DEFAULT_RULES_REQUEST_OPTIONS = {
      ok: DEFAULT_OK_RESPONSE_STATUS,
      headers: {},
      body: nil
    }

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

    def parse_json_body(body)
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

    # Returns the type of message received on the stream, nil when the type
    # cannot be identified.
    def message_type(message)
      case message
      when HEARTBEAT_MESSAGE_PATTERN then :heartbeat
      when SYSTEM_MESSAGE_PATTERN then :system
      when ACTIVITY_MESSAGE_PATTERN then :activity
      else
        nil
      end
    end

    # Connects to the /track endpoint and manages reconnections when being
    # disconnected.
    def track_and_reconnect(buffer, options, retries=0)
      $stderr.puts "Retries: #{retries}"
      max_retries = options[:max_retries]
      stop_timeout = options[:stop_timeout]

      on_heartbeat = options[:on_heartbeat]
      on_message = options[:on_message]
      on_activity = options[:on_activity]
      close_now = options[:close_now] || lambda { false }

      closed = false
      disconnected = false
      resp_status = DEFAULT_OK_RESPONSE_STATUS
      resp_error = nil
      resp_body = nil

      con = connect('stream')
      http = con.get(head: track_req_headers(options[:compressed]))

      # polls to see if the connection should be closed
      close_watcher = EM.add_periodic_timer(1) do
        $stderr.puts "#{Time.now}: time to close ?"
        # exit if required
        if close_now.call
          $stderr.puts "Time to close !"
          closed = true
          close_watcher.cancel
          # TODO: find a way to make a graceful close connection
          con.unbind
        end
      end

      # simulate periodic disconnections
      if options[:fake_disconnections]
         EM.add_timer(rand(options[:fake_disconnections])) do
           con.unbind
         end
      end

      http.stream do |chunk|
        # ignore data if already disconnected, thus avoiding synchronizing the
        # buffer. Nevertheless, this should never happen...
        # TODO: log a warning if it happens
        next if disconnected

        # reset retries when some (valid) data are received
        retries = 0

        # process the chunk
        buffer.process(chunk) do |raw|
          EM.defer do
            # select the right message handler(s) according to the message type
            m_type = message_type(raw)

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
        $stderr.puts "Disconnection after #{retries} retries"
        disconnected = true

        if closed
          # close immediately if required
          wait_til_defers_finish_and_stop(stop_timeout)
        else
          # cancel the periodic close watcher
          close_watcher.cancel

          if retries < max_retries
            # retry once
            resp_status, resp_error, resp_body = track_and_reconnect(buffer, options, retries + 1)
          else
            resp_status = http_client.response_header.status || DEFAULT_OK_RESPONSE_STATUS
            resp_error = http_client.error
            resp_body = http_client.response
            wait_til_defers_finish_and_stop(stop_timeout)
          end
        end
      end

      http.callback(&reconnect_cb)
      http.errback(&reconnect_cb)

      [ resp_status, resp_error, resp_body ]
    end

    # Waits for all the deferrable threads to complete, then stops the reactor.
    def wait_til_defers_finish_and_stop(timeout)
      Timeout::timeout(timeout) do
        sleep(1) unless EM.defers_finished?
      end
    ensure
      EM.stop
    end
  end
end
