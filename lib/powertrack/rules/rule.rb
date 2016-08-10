require 'multi_json'

module PowerTrack
  # A PowerTrack rule with its components and restrictions.
  class Rule

    # The maximum length of a rule tag.
    MAX_TAG_LENGTH = 255

    # The maximum lengh of the value of a standard rule
    MAX_STD_RULE_VALUE_LENGTH = 1024

    # The maximum lengh of the value of a long rule
    MAX_LONG_RULE_VALUE_LENGTH = 2048

    # The maximum number of positive terms in a single rule value
    MAX_POSITIVE_TERMS = 30

    # The maximum number of negative terms in a single rule value
    MAX_NEGATIVE_TERMS = 50

    # The default rule features
    DEFAULT_RULE_FEATURES = {
      # no id by default
      id: nil,
      # no tag by default
      tag: nil,
      # long determined by value length
      long: nil
    }.freeze

    attr_reader :value, :id, :tag, :error

    # Builds a new rule based on a value and some optional features
    # (:id, :tag, :long).
    #
    # By default, the constructor assesses if it's a long rule or not
    # based on the length of the value. But the 'long' feature can be
    # explicitly specified with the :long feature.
    def initialize(value, features=nil)
      @value = value || ''
      features = DEFAULT_RULE_FEATURES.merge(features || {})
      @tag = features[:tag]
      @id = features[:id]
      # check if long is a boolean
      _long = features[:long]
      @long = _long == !!_long ? _long : @value.size > MAX_STD_RULE_VALUE_LENGTH
      @error = nil
    end

    # Returns true if the rule is long.
    def long?
      @long
    end

    # Returns true if the rule is valid, false otherwise. The validation error
    # can be through the error method.
    def valid?
      # reset error
      @error = nil

      [ :too_long_value?,
        :too_many_positive_terms?,
        :too_many_negative_terms?,
        :contains_empty_source?,
        :contains_negated_or?,
        :too_long_tag? ].each do |validator|

        # stop when 1 validator fails
        if self.send(validator)
          @error = validator.to_s.gsub(/_/, ' ').gsub(/\?/, '').capitalize
          return false
        end
      end

      true
    end

    # Dumps the rule in a valid JSON format.
    def to_json(options={})
      MultiJson.encode(to_hash, options)
    end

    # Converts the rule in a Hash.
    def to_hash
      res = {:value => @value}
      res[:tag] = @tag unless @tag.nil?
      res[:id] = @id unless @id.nil?
      res
    end

    # Converts the rule in a string, the JSON representation of the rule actually.
    def to_s
      to_json
    end

    # Returns true when the rule is equal to the other rule provided.
    def ==(other)
      other.class == self.class &&
        other.value == @value &&
        other.tag == @tag &&
        other.long? == self.long?
    end

    alias eql? ==

    # Returns a hash for the rule based on its components. Useful for using
    # rules as Hash keys.
    def hash
      # let's assume a nil value for @value or @tag is not different from the empty value
      "v:#{@value},t:#{@tag},l:#{@long}".hash
    end

    # Returns the maximum length of the rule value according to the type of the
    # rule (long or standard).
    def max_value_length
      long? ? MAX_LONG_RULE_VALUE_LENGTH : MAX_STD_RULE_VALUE_LENGTH
    end

    protected

    # Is the rule value too long ?
    def too_long_value?
      @value.size > max_value_length
    end

    # Does the rule value contain a forbidden negated OR ?
    def contains_negated_or?
      !@value[/\-\w+ OR/].nil? || !@value[/OR \-\w+/].nil?
    end

    # Does the rule value contain too many positive terms ?
    def too_many_positive_terms?
      return false if long?
      # negative look-behind; see http://www.rexegg.com/regex-disambiguation.html
      # exclude the OR operator from the terms being counted
      @value.scan(/(?<!-)(\b[\w:]+|\"[\-\s\w:]+\"\b)/).select { |match| match.first != 'OR' }.size > MAX_POSITIVE_TERMS
    end

    # Does the rule value contain too many negative terms ?
    def too_many_negative_terms?
      return false if long?
      @value.scan(/(^| )\-(\w|\([^(]*\)|\"[^"]*\")/).size > MAX_NEGATIVE_TERMS
    end

    # Does the rule value contain an empty source ?
    def contains_empty_source?
      !@value[/source\:\s/].nil?
    end

    # Is the rule tag too long ?
    def too_long_tag?
      @tag && @tag.size > MAX_TAG_LENGTH
    end
  end
end
