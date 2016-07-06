require 'minitest_helper'
require 'powertrack'
require 'multi_json'

class TestTrackStream < Minitest::Test

  def test_track_realtime_stream
    track_simple_stream(false)
  end

  def test_track_replay_stream
    track_simple_stream(true)
  end

  def track_simple_stream(replay)
    stream = new_stream(replay)

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
      from = nil
      to = nil

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
      on_system = lambda do |message|
        $stderr.puts message.inspect
      end

      close_now = lambda { closed }

      if replay
        now = Time.now
        from = now - 31*60
        to = now - 30*60
        delay = to - from
      else
        delay = 60
        Thread.new do
          $stderr.puts "Time-bomb thread running for #{delay} seconds..."
          sleep delay
          $stderr.puts "Time to shut down !"
          closed = true
        end
      end

      started_at = Time.now
      res = stream.track(on_message: on_message,
                         on_heartbeat: on_heartbeat,
                         on_activity: on_activity,
                         on_system: on_system,
                         close_now: close_now,
                         max_retries: 2,
                         fake_disconnections: replay ? nil : 20,
                         from: from,
                         to: to)

      ended_at = Time.now

      assert_nil res
      assert replay || closed, 'Stream not closed'

      if replay
        assert (ended_at - started_at) <= delay
      else
        assert (ended_at - started_at) >= delay
      end

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
