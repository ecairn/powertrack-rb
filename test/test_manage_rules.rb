require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestManageRules < Minitest::Test

  def test_add_then_delete_a_single_rule
    stream = new_stream

    rule = PowerTrack::Rule.new('coke')
    assert rule.valid?

    pre_existing_rules = stream.list_rules
    assert pre_existing_rules.is_a?(Array)

    assert_nil stream.add_rule(rule)

    rules_after_addition = stream.list_rules(false)
    assert rules_after_addition.is_a?(Array)
    assert_equal pre_existing_rules.size + 1, rules_after_addition.size
    assert [ rule ], rules_after_addition - pre_existing_rules

    assert_nil stream.delete_rules(rule)

    rules_after_removal = stream.list_rules
    assert rules_after_removal.is_a?(Array)
    assert_equal rules_after_addition.size - 1, rules_after_removal.size
    assert_equal [], rules_after_removal - rules_after_addition
  end
end
