module PowerTrack
  module API
    # Adds many rules to your PowerTrack stream’s ruleset.
    #
    # <tt>POST /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#AddRules
    def add_rules(*rules)
      raise NotImplementedError
    end

    # Adds one rule to your PowerTrack stream’s ruleset.
    #
    # <tt>POST /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#AddRules
    def add_rule(rule)
      add_rules(rule)
    end

    # Removes the specified rules from the stream.
    #
    # <tt>DELETE /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#DeleteRules
    def delete_rules(*rules)
      raise NotImplementedError
    end

    # Removes the specified rule from the stream.
    #
    # <tt>DELETE /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#DeleteRules
    def delete_rule(rule)
      delete_rules(rule)
    end

    # Retrieves all existing rules for a stream.
    #
    # <tt>GET /rules</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#ListRules
    #
    # Options:
    # o compressed: [true|false] To demand gzip-compressed response from GNIP
    #               true by default
    # o objectify: [true|false] To demand PowerTrack::Rule object as results
    #              instead of raw JSON. True by default.
    def list_rules(options=nil)
      raise NotImplementedError
    end

    # Establishes a persistent connection to the PowerTrack data stream,
    # through which the social data will be delivered.
    #
    # <tt>GET /track/:stream</tt>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#Stream
    def track(options=nil)
      raise NotImplementedError
    end
  end
end
