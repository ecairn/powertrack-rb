module PowerTrack
  module API
    # Adds many rules to your PowerTrack stream’s ruleset.
    #
    # <pre>POST /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#AddRules
    def add_rules(*rules)
      raise NotImplementedError
    end

    # Adds one rule to your PowerTrack stream’s ruleset.
    #
    # <pre>POST /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#AddRules
    def add_rule(rule)
      add_rules(rule)
    end

    # Removes the specified rules from the stream.
    #
    # <pre>DELETE /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#DeleteRules
    def delete_rules(*rules)
      raise NotImplementedError
    end

    # Removes the specified rule from the stream.
    #
    # <pre>DELETE /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#DeleteRules
    def delete_rule(rule)
      delete_rules(rule)
    end

    # Retrieves all existing rules for a stream.
    #
    # <pre>GET /rules</pre>
    #
    # See http://support.gnip.com/apis/powertrack/api_reference.html#ListRules
    def list_rules(compressed=true)
      raise NotImplementedError
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
  end
end
