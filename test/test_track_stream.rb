require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestTrackStream < Minitest::Test

  def test_track_simple_stream
    stream = new_stream

    rule = PowerTrack::Rule.new('ny OR nyc OR #nyc OR new york')
    assert rule.valid?

    begin
      assert_nil stream.add_rule(rule)
      rules_after_addition = stream.list_rules
      assert rules_after_addition.is_a?(Array)
      assert rules_after_addition.size > 0

      $stderr.puts rules_after_addition.inspect

      heartbeaten = false
      received = false
      tweeted = false
      closed = false

      # ready to track
      on_message = lambda { |message| received = true }
      on_heartbeat = lambda { heartbeaten = true }
      on_activity = lambda { |tweet| tweeted = true }
      close_now = lambda { closed }

      delay = 60
      Thread.new do
        $stderr.puts "Time-bomb thread running for #{delay} seconds..."
        sleep delay
        $stderr.puts "Time to shut down !"
        closed = true
      end

      started_at = Time.now
      res = stream.track(on_message: on_message,
                         on_heartbeat: on_heartbeat,
                         on_activity: on_activity,
                         close_now: close_now,
                         max_retries: 3,
                         fake_disconnections: 20)

      assert_nil res
      assert closed, 'Stream not closed'
      assert Time.now - started_at >= delay
      assert heartbeaten, 'No heartbeat received'
      assert received, 'No message received so far'
      assert tweeted, 'No tweet received so far'
    ensure
      assert_nil stream.delete_rules(rule)
    end
  end
end
