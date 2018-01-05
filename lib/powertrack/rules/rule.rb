require 'multi_json'

module PowerTrack
  # A PowerTrack rule with its components and restrictions.
  class Rule

    # The maximum length of a rule tag.
    MAX_TAG_LENGTH = 255

    # The maximum lengh of the value of a rule
    MAX_RULE_VALUE_LENGTH = 2048

    # The maximum number of positive terms in a single rule value
    MAX_POSITIVE_TERMS = 30

    # The maximum number of negative terms in a single rule value
    MAX_NEGATIVE_TERMS = 50

    # The maximum size of the HTTP body accepted by PowerTrack /rules calls (in bytes)
    # 5MB since v2
    MAX_RULES_BODY_SIZE = 5*1024**2

    # The default rule features
    DEFAULT_RULE_FEATURES = {
      # no id by default
      id: nil,
      # no tag by default
      tag: nil
    }.freeze

    attr_reader :value, :id, :tag, :error

    # Builds a new rule based on a value and some optional features
    # (:id, :tag).
    def initialize(value, features=nil)
      @value = value || ''
      features = DEFAULT_RULE_FEATURES.merge(features || {})
      @tag = features[:tag]
      @id = features[:id]
      @error = nil
    end

    # Returns true if the rule is valid, false otherwise. The validation error
    # can be through the error method.
    def valid?
      # reset error
      @error = nil

      validation_rules = [
        :too_long_value?,
        :contains_empty_source?,
        :contains_negated_or?,
        :too_long_tag?,
        :contains_explicit_and?,
        :contains_lowercase_or?,
        :contains_explicit_not?
      ]

      validation_rules.each do |validator|
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
        other.tag == @tag
    end

    alias eql? ==

    # Returns a hash for the rule based on its components. Useful for using
    # rules as Hash keys.
    def hash
      # let's assume a nil value for @value or @tag is not different from the empty value
      "v:#{@value},t:#{@tag}".hash
    end

    # Returns the maximum length of the rule value.
    def max_value_length
      MAX_RULE_VALUE_LENGTH
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

    # Does the rule value contain a forbidden AND ?
    def contains_explicit_and?
      !@value[/ AND /].nil?
    end

    # Does the rule value contain a forbidden lowercase or ?
    def contains_lowercase_or?
      !@value[/ or /].nil?
    end

    # Does the rule value contain a forbidden NOT ?
    def contains_explicit_not?
      !@value[/(^| )NOT /].nil?
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
