require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestRule < Minitest::Test

  def test_add_a_single_rule
    stream = PowerTrack::Stream.new(
      'laurent.farcy@ecairn.com',
      'piodv-717',
      'eCairn',
      'twitter',
      'prod')

    rule = PowerTrack::Rule.new('coke')
    p stream.list_rules
    p stream.add_rule(rule)
    p stream.list_rules(false)
    p stream.delete_rules(rule)
    p stream.list_rules
  end
end
