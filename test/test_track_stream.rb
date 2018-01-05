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

    new_rule = PowerTrack::Rule.new('ny OR nyc OR #nyc OR new york')
    assert new_rule.valid?

    begin
      res = stream.add_rule(new_rule)

      assert res.is_a?(Hash)
      assert res['summary'].is_a?(Hash)

      rules_after_addition = stream.list_rules
      assert rules_after_addition.is_a?(Array)
      assert rules_after_addition.size > 0
      assert rules_after_addition.any? { |rule| rule == new_rule }
      assert rules_after_addition.all? { |rule| !rule.id.nil? }

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

      # a replay may take longer than the delay it passes over...
      unless replay
        assert (ended_at - started_at) >= delay, "#{ended_at - started_at}s < #{delay}s"
      end

      # heartbeats only sent every 10 minutes in v2...
      unless replay
        assert_equal 0, heartbeats, "Unexpected #{heartbeats} heartbeats received"
      else
        assert heartbeats > 0, 'No heartbeats received so far'
        puts "#{heartbeats} heartbeats received"
      end

      assert received > 0, 'No message received so far'
      puts "#{received} messages received"

      assert tweeted > 0, 'No tweet received so far'
      puts "#{tweeted} tweets received"
    rescue
      p $!
    ensure
      res = stream.delete_rules(new_rule)

      assert res.is_a?(Hash)
      assert res['summary'].is_a?(Hash)
      assert_equal 1, res['summary']['deleted']
      assert_equal 0, res['summary']['not_deleted']
    end
  end
end
