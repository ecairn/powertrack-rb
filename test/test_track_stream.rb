require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestTrackStream < Minitest::Test

  def test_track_simple_stream
    stream = new_stream

    # add a logger
    stream.logger = Logger.new(STDERR)

    rule = PowerTrack::Rule.new('ny OR nyc OR #nyc OR new york')
    assert rule.valid?

    begin
      assert_nil stream.add_rule(rule)
      rules_after_addition = stream.list_rules
      assert rules_after_addition.is_a?(Array)
      assert rules_after_addition.size > 0

      heartbeats = 0
      received = 0
      tweeted = 0
      closed = false

      # ready to track
      on_message = lambda do |message|
        received += 1
      end
      on_heartbeat = lambda do
        heartbeats += 1
      end
      on_activity = lambda do |tweet|
        tweeted += 1
      end

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

      assert heartbeats > 0, 'No heartbeat received'
      puts "#{heartbeats} heartbeats received"

      assert received > 0, 'No message received so far'
      puts "#{received} messages received"

      assert tweeted > 0, 'No tweet received so far'
      puts "#{tweeted} tweets received"
    ensure
      assert_nil stream.delete_rules(rule)
    end
  end
end
