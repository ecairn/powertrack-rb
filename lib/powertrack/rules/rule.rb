require 'multi_json'

module PowerTrack
  class Rule

    MAX_TAG_LENGTH = 255
    MAX_STD_RULE_VALUE_LENGTH = 1024
    MAX_LONG_RULE_VALUE_LENGTH = 2048
    MAX_POSITIVE_TERMS = 30
    MAX_NEGATIVE_TERMS = 50

    attr_reader :value, :tag, :error

    def initialize(value, long=false, tag=nil)
      @value = value
      @long = long
      @tag = tag
      @error = nil
    end

    def long?
      !!@long
    end

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

    def to_json
      MultiJson.dump(to_hash)
    end

    def to_hash
      obj = {:value => @value}
      obj[:tag] = @tag unless @tag.nil?
      obj
    end

    def to_s
      to_json
    end

    def max_value_length
      long? ? MAX_LONG_RULE_VALUE_LENGTH : MAX_STD_RULE_VALUE_LENGTH
    end

    protected

    def too_long_value?
      @value.size > max_value_length
    end

    def contains_negated_or?
      !@value[/\-\w+ OR/].nil? || !@value[/OR \-\w+/].nil?
    end

    def too_many_positive_terms?
      return false if long?
      # negative look-behind; see http://www.rexegg.com/regex-disambiguation.html
      @value.scan(/(?<!-)(\b\w+|\"[\-\s\w]+\"\b)/).size > MAX_POSITIVE_TERMS
    end

    def too_many_negative_terms?
      return false if long?
      @value.scan(/(^| )\-(\w|\([^(]*\)|\"[^"]*\")/).size > MAX_NEGATIVE_TERMS
    end

    def contains_empty_source?
      !@value[/source\:\s/].nil?
    end

    def too_long_tag?
      @tag && @tag.size > MAX_TAG_LENGTH
    end
  end
end
