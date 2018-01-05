require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestManageRules < Minitest::Test

  def test_add_then_delete_a_single_rule
    add_then_delete_a_single_rule(false)
  end

  def test_add_then_delete_a_single_rule_in_replay_mode
    add_then_delete_a_single_rule(true)
  end

  def add_then_delete_a_single_rule(replay)
    stream = new_stream(replay)

    # add a logger
    stream.logger = Logger.new(STDERR)

    new_rule = PowerTrack::Rule.new('coke')
    assert new_rule.valid?

    pre_existing_rules = stream.list_rules
    $stderr.puts pre_existing_rules.inspect
    assert pre_existing_rules.is_a?(Array)
    assert pre_existing_rules.all? { |rule| !rule.id.nil? }

    already_in = pre_existing_rules.any? { |rule| new_rule == rule }

    res = stream.add_rule(new_rule)

    assert res.is_a?(Hash)
    assert res['summary'].is_a?(Hash)

    if already_in
      assert_equal 0, res['summary']['created']
      assert_equal 1, res['summary']['not_created']
    else
      assert_equal 1, res['summary']['created']
      assert_equal 0, res['summary']['not_created']
    end

    rules_after_addition = stream.list_rules
    assert rules_after_addition.is_a?(Array)
    assert rules_after_addition.all? { |rule| !rule.id.nil? }

    if already_in
      assert_equal pre_existing_rules.size, rules_after_addition.size
      assert [], rules_after_addition - pre_existing_rules
    else
      assert_equal pre_existing_rules.size + 1, rules_after_addition.size
      assert [ new_rule ], rules_after_addition - pre_existing_rules
    end

    res = stream.delete_rules(new_rule)

    assert res.is_a?(Hash)
    assert res['summary'].is_a?(Hash)
    assert_equal 1, res['summary']['deleted']
    assert_equal 0, res['summary']['not_deleted']

    rules_after_removal = stream.list_rules
    assert rules_after_removal.is_a?(Array)
    assert_equal rules_after_addition.size - 1, rules_after_removal.size
    assert_equal [], rules_after_removal - rules_after_addition
    assert rules_after_removal.all? { |rule| !rule.id.nil? }
  end
end
