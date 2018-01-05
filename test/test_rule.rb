require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestRule < Minitest::Test

  def test_valid_rule
    rule = PowerTrack::Rule.new('coke')
    assert_equal 'coke', rule.value
    assert_nil rule.tag
    assert rule.valid?
    assert_nil rule.error

    tagged_rule = PowerTrack::Rule.new('dr pepper', tag: 'soda')
    assert_equal 'dr pepper', tagged_rule.value
    assert_equal 'soda', tagged_rule.tag
    assert tagged_rule.valid?
    assert_nil tagged_rule.error
  end

  def test_too_long_tag
    long_tag = 'a' * PowerTrack::Rule::MAX_TAG_LENGTH
    rule = PowerTrack::Rule.new('coke', tag: long_tag)
    assert rule.valid?
    assert_nil rule.error

    long_tag = 'b' * 2 * PowerTrack::Rule::MAX_TAG_LENGTH
    rule = PowerTrack::Rule.new('coke', tag: long_tag)
    assert !rule.valid?
    assert_match /too long tag/i, rule.error
  end

  def test_too_long_value
    long_val = 'a' * PowerTrack::Rule::MAX_RULE_VALUE_LENGTH

    rule = PowerTrack::Rule.new(long_val)
    assert rule.valid?
    assert_nil rule.error

    long_val = 'c' * PowerTrack::Rule::MAX_RULE_VALUE_LENGTH
    assert long_val.to_pwtk_rule.valid?

    very_long_val = 'rrr' * PowerTrack::Rule::MAX_RULE_VALUE_LENGTH
    rule = very_long_val.to_pwtk_rule
    assert !rule.valid?
    assert_match /too long value/i, rule.error
  end

  def test_contains_negated_or
    phrase = 'coke OR -pepsi'
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.valid?
    assert_match /contains negated or/i, rule.error
  end

  def test_contains_explicit_and
    phrase = 'coke AND pepsi'
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.valid?
    assert_match /contains explicit and/i, rule.error
  end

  def test_contains_explicit_not
    [ 'coke NOT pepsi', 'NOT (pepsi OR "dr pepper")' ].each do |phrase|
      rule = PowerTrack::Rule.new(phrase)
      assert !rule.valid?
      assert_match /contains explicit not/i, rule.error
    end
  end

  def test_contains_lowercase_or
    phrase = 'coke or pepsi'
    rule = PowerTrack::Rule.new(phrase)
    assert !rule.valid?
    assert_match /contains lowercase or/i, rule.error
  end

  def test_to_hash_and_json
    res = { value: 'coke OR pepsi' }
    rule = PowerTrack::Rule.new(res[:value])
    assert_equal res, rule.to_hash
    assert_equal MultiJson.encode(res), rule.to_json

    res[:tag] = 'soda'
    rule = PowerTrack::Rule.new(res[:value], tag: res[:tag])
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
    short_rule_with_tag = PowerTrack::Rule.new('coke', tag: 'soda')

    h = { short_rule => 1 }
    h[short_rule_with_tag] = 4

    assert_equal 1, h[short_rule]
    assert_equal 4, h[short_rule_with_tag]
    assert_nil h[PowerTrack::Rule.new('pepsi', tag: 'soda')]
  end
end
