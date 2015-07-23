require 'eventmachine'
require 'em-http-request'
require 'multi_json'

require 'powertrack/errors'
require 'powertrack/streaming/api'

module PowerTrack
  class Stream
    include PowerTrack::API

    FEATURE_URL_FORMAT = "https://%s.gnip.com/accounts/%s/publishers/%s/streams/track/%s/%s.json"
    DEFAULT_CONNECTION_TIMEOUT = 30
    DEFAULT_INACTIVITY_TIMEOUT = 50
    DEFAULT_CLIENT_ID = 1

    DEFAULT_STREAM_OPTIONS = {
      connect_timeout: DEFAULT_CONNECTION_TIMEOUT,
      inactivity_timeout: DEFAULT_INACTIVITY_TIMEOUT,
      client_id: DEFAULT_CLIENT_ID
    }

    DEFAULT_OK_RESPONSE_STATUS = 200

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

    # Retrieves all existing rules for a stream.
    #
    # <pre>GET /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#ListRules
    def list_rules(compressed=true)
      headers = compressed ? { 'accept-encoding' => 'gzip, compressed' } : {}
      res = make_rules_request(:get, headers: headers)
      res.is_a?(Hash) && res.key?('rules') ? res['rules'] : res
    end

    # Establishes a persistent connection to the PowerTrack data stream,
    # through which the social data will be delivered.
    #
    # <pre>GET /track/:stream</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#Stream
    def track(compressed=true)
      raise NotImplementedError
    end

    private

    # Returns the URL of the stream for a given feature.
    def feature_url(hostname, feature)
      _url = FEATURE_URL_FORMAT % [ hostname, @account_name, @data_source, @label, feature ]
      _url += "?client=#{@client_id}" if @client_id

      _url
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
    def connect(hostname, feature)
      url = feature_url(hostname, feature)
      EventMachine::HttpRequest.new(url, connection_headers)
    end

    DEFAULT_RULES_REQUEST_OPTIONS = {
      ok: DEFAULT_OK_RESPONSE_STATUS,
      headers: {},
      body: nil
    }

    # Returns the HTTP headers common to each valid /rules request.
    # Each call returns a new hash which can be safely modified by the caller.
    def rules_req_headers
      { 'accept' => 'application/json',
        'content-type' => 'application/json; charset=utf-8',
        :redirects => 3 }.merge(auth_header)
    end

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

      handle_rules_response(resp_status, resp_error, resp_body, options[:ok])
    end

    def handle_rules_response(status, error, body, ok)
      case status
      when nil
        # connection issue
        raise PowerTrack::ConnectionError(error)
      when ok
        # successful call
        parse_json_body(body) do |exception|
          # invalid JSON response
          raise PowerTrack::InvalidResponseError.new(ok, exception.message, body)
        end
      else
        # non-specified response status
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
  end
end
