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

    rule = PowerTrack::Rule.new('pepsi', 'soda', true)
    assert_equal 'pepsi', rule.value
    assert_equal 'soda', rule.tag
    assert rule.long?
    assert rule.valid?
    assert_nil rule.error
  end

  def test_too_long_tag
    long_tag = 'a' * PowerTrack::Rule::MAX_TAG_LENGTH
    rule = PowerTrack::Rule.new('coke', long_tag, false)
    assert rule.valid?
    assert_nil rule.error

    long_tag = 'b' * 2 * PowerTrack::Rule::MAX_TAG_LENGTH
    rule = PowerTrack::Rule.new('coke', long_tag, true)
    assert !rule.valid?
    assert_match /too long tag/i, rule.error
  end

  def test_too_long_value
    long_val = 'a' * PowerTrack::Rule::MAX_STD_RULE_VALUE_LENGTH
    rule = PowerTrack::Rule.new(long_val)
    assert rule.valid?

    long_val = 'c' * PowerTrack::Rule::MAX_LONG_RULE_VALUE_LENGTH
    rule = long_val.to_pwtk_rule(nil, false)

    assert !rule.valid?
    assert_match /too long value/i, rule.error

    assert long_val.to_pwtk_rule.valid?
    assert long_val.to_pwtk_rule(nil, true).valid?

    very_long_val = 'rrr' * PowerTrack::Rule::MAX_LONG_RULE_VALUE_LENGTH
    rule = very_long_val.to_pwtk_rule
    assert !rule.valid?
    assert_match /too long value/i, rule.error
  end

  def test_too_many_positive_terms
    phrase = ([ 'coke' ] * PowerTrack::Rule::MAX_POSITIVE_TERMS).join(' ')
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert rule.valid?
    assert_nil rule.error

    long_rule = PowerTrack::Rule.new(phrase, nil, true)
    assert long_rule.long?
    assert long_rule.valid?
    assert_nil long_rule.error

    phrase = ([ 'coke' ] * (2 * PowerTrack::Rule::MAX_POSITIVE_TERMS)).join(' ')
    rule = PowerTrack::Rule.new(phrase, nil, false)
    assert !rule.long?
    assert !rule.valid?
    assert_match /too many positive terms/i, rule.error

    long_rule = PowerTrack::Rule.new(phrase, nil, true)
    assert long_rule.long?
    assert long_rule.valid?
    assert_nil long_rule.error

    phrase = "from:lkv1csayp OR from:u42vf OR from:y OR from:groj OR from:69iqciuxlxerqq OR from:4 OR from:9832xjrqi1ncrs OR from:7kfss6jxtl0oj OR from:b31m9qf0u3tc OR from:0 OR from:abo59n OR from:3lma3kl OR from:5 OR from:ovw7bgov OR from:ubp OR from:gc9a6b OR from:jo7ootfvy4 OR from:sg7oohj OR from:349ankku OR from:9b72n OR from:qz7offt5019u OR from:gkd OR from:cc31p3 OR from:xws9 OR from:bjzbatm OR from:rwjm78cgre3j5 OR from:f1obak7w3w OR from:nontf OR from:4aeas6kgb7nia OR from:dzqy7"
    long_rule = PowerTrack::Rule.new(phrase)
    assert !long_rule.long?
    assert long_rule.valid?, long_rule.error
    assert_nil long_rule.error

    long_rule = PowerTrack::Rule.new(phrase + " OR from:michel")
    assert !rule.valid?
    assert_match /too many positive terms/i, rule.error
  end

  def test_too_many_negative_terms
    phrase = ([ '-pepsi' ] * PowerTrack::Rule::MAX_POSITIVE_TERMS).join(' ')
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert rule.valid?
    assert_nil rule.error

    long_rule = PowerTrack::Rule.new(phrase, nil, true)
    assert long_rule.long?
    assert long_rule.valid?
    assert_nil long_rule.error

    phrase = ([ '-pepsi' ] * (2 * PowerTrack::Rule::MAX_POSITIVE_TERMS)).join(' ')
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.long?
    assert !rule.valid?
    assert_match /too many negative terms/i, rule.error

    long_rule = PowerTrack::Rule.new(phrase, nil, true)
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
    assert_equal MultiJson.encode(res), rule.to_json

    res[:tag] = 'soda'
    rule = PowerTrack::Rule.new(res[:value], res[:tag], true)
    assert_equal res, rule.to_hash
    assert_equal MultiJson.encode(res), rule.to_json
  end

  def test_double_quote_jsonification
    rule = PowerTrack::Rule.new('"social data" @gnip')
    assert_equal '{"value":"\"social data\" @gnip"}', rule.to_json

    rule = PowerTrack::Rule.new('Toys \"R\" Us')
    # 2 backslashes for 1
    assert_equal '{"value":"Toys \\\\\\"R\\\\\\" Us"}', rule.to_json
  end

  def test_hash
    short_rule = PowerTrack::Rule.new('coke')
    not_long_rule = PowerTrack::Rule.new('coke', nil, false)
    false_long_rule = PowerTrack::Rule.new('coke', nil, true)
    short_rule_with_tag = PowerTrack::Rule.new('coke', 'soda')

    assert short_rule == not_long_rule
    assert_equal short_rule, not_long_rule
    assert_equal short_rule.hash, not_long_rule.hash

    assert short_rule != false_long_rule
    h = { short_rule => 1 }
    h[not_long_rule] = 2
    h[false_long_rule] = 3
    h[short_rule_with_tag] = 4

    assert_equal 2, h[short_rule]
    assert_equal h[short_rule], h[not_long_rule]
    assert_equal 4, h[short_rule_with_tag]
    assert_nil h[PowerTrack::Rule.new('pepsi', 'soda')]
  end
end
