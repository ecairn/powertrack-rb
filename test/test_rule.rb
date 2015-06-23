require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestRule < Minitest::Test

  def test_valid_rule
    rule = PowerTrack::Rule.new('coke')
    assert_equal 'coke', rule.value
    assert_nil rule.tag
    assert !rule.long?
    assert rule.valid?
    assert_nil rule.error

    rule = PowerTrack::Rule.new('pepsi', true, 'soda')
    assert_equal 'pepsi', rule.value
    assert_equal 'soda', rule.tag
    assert rule.long?
    assert rule.valid?
    assert_nil rule.error
  end

  def test_too_long_tag
    long_tag = 'a' * PowerTrack::Rule::MAX_TAG_LENGTH
    rule = PowerTrack::Rule.new('coke', false, long_tag)
    assert rule.valid?
    assert_nil rule.error

    long_tag = 'b' * 2 * PowerTrack::Rule::MAX_TAG_LENGTH
    rule = PowerTrack::Rule.new('coke', true, long_tag)
    assert !rule.valid?
    assert_match /too long tag/i, rule.error
  end

  def test_too_long_value
    long_val = 'a' * PowerTrack::Rule::MAX_STD_RULE_VALUE_LENGTH
    rule = PowerTrack::Rule.new(long_val)
    assert rule.valid?

    long_val = 'c' * PowerTrack::Rule::MAX_LONG_RULE_VALUE_LENGTH
    rule = long_val.to_pwtk_rule
    assert !rule.valid?
    assert_match /too long value/i, rule.error

    assert long_val.to_pwtk_rule(true).valid?

    very_long_val = 'rrr' * PowerTrack::Rule::MAX_LONG_RULE_VALUE_LENGTH
    rule = very_long_val.to_pwtk_rule(true)
    assert !rule.valid?
    assert_match /too long value/i, rule.error
  end

  def test_too_many_positive_terms
    phrase = ([ 'coke' ] * PowerTrack::Rule::MAX_POSITIVE_TERMS).join(' ')
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert rule.valid?
    assert_nil rule.error

    long_rule = PowerTrack::Rule.new(phrase, true)
    assert long_rule.long?
    assert long_rule.valid?
    assert_nil long_rule.error

    phrase = ([ 'coke' ] * (2 * PowerTrack::Rule::MAX_POSITIVE_TERMS)).join(' ')
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert !rule.valid?
    assert_match /too many positive terms/i, rule.error

    long_rule = PowerTrack::Rule.new(phrase, true)
    assert long_rule.long?
    assert long_rule.valid?
    assert_nil long_rule.error
  end

  def test_too_many_negative_terms
    phrase = ([ '-pepsi' ] * PowerTrack::Rule::MAX_POSITIVE_TERMS).join(' ')
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert rule.valid?
    assert_nil rule.error

    long_rule = PowerTrack::Rule.new(phrase, true)
    assert long_rule.long?
    assert long_rule.valid?
    assert_nil long_rule.error

    phrase = ([ '-pepsi' ] * (2 * PowerTrack::Rule::MAX_POSITIVE_TERMS)).join(' ')
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert !rule.valid?
    assert_match /too many negative terms/i, rule.error

    long_rule = PowerTrack::Rule.new(phrase, true)
    assert long_rule.long?
    assert long_rule.valid?
    assert_nil long_rule.error
  end

  def test_contains_negated_or
    phrase = 'coke OR -pepsi'
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert !rule.valid?
    assert_match /contains negated or/i, rule.error
  end

  def test_to_hash_and_json
    res = { value: 'coke OR pepsi' }
    rule = PowerTrack::Rule.new(res[:value])
    assert_equal res, rule.to_hash
    assert_equal MultiJson.dump(res), rule.to_json

    res[:tag] = 'soda'
    rule = PowerTrack::Rule.new(res[:value], true, res[:tag])
    assert_equal res, rule.to_hash
    assert_equal MultiJson.dump(res), rule.to_json
  end

  def test_double_quote_jsonification
    rule = PowerTrack::Rule.new('"social data" @gnip')
    assert_equal '{"value":"\"social data\" @gnip"}', rule.to_json

    rule = PowerTrack::Rule.new('Toys \"R\" Us')
    # 2 backslashes for 1
    assert_equal '{"value":"Toys \\\\\\"R\\\\\\" Us"}', rule.to_json
  end
end
