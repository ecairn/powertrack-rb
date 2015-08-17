# powertrack-rb
A Ruby gem for building GNIP PowerTrack streaming clients.

## How to use it ?

1. Create a PowerTrack stream based on your credentials

  ```ruby
  require 'powertrack'

  stream = PowerTrack::Stream.new(
    powertrack_config[:username],
    powertrack_config[:password],
    powertrack_config[:account_name],
    powertrack_config[:data_source],  # often 'twitter'
    powertrack_config[:stream_label]) # often 'prod'
  ```

2. Add a few rules to the stream

  ```ruby
  rule = PowerTrack::Rule.new('coke')
  if rule.valid?
    stream.add_rule(rule)
    # double-check that the rule was actually added
    raise 'Fail to add a rule' unless stream.list_rules.include?(rule)
  end
  ```

3. Get the activities out of the stream

  ```ruby
  received, heartbeats = 0, 0
  activities = []

  ## defining callbacks on messages received
  # callback triggered for each message received
  on_message = lambda { |message| received += 1 }
  # callback triggered for each heartbeat received
  on_heartbeat = lambda { heartbeats += 1 }
  # callback triggered for each activity received
  on_activity = lambda { |activity| activities += activity }

  ## defining the block that will command the stop of the tracking
  closed = false
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
                     close_now: close_now)

  puts "After #{delay} seconds tracking '#{rule.value}':"
  puts "  o #{received} messages received"
  puts "  o #{heartbeats} heartbeats received"
  puts "  o #{activities.size} activities captured"
  ```

Please note that each message callback must be thread-safe since it can be called
multiple times simultaneously.

## Tracking response format

By default, messages received are passed to callbacks as plain Ruby objects. Enable
the ```raw``` option to get raw JSON-formatted string and make the parsing by
yourself.

## Stop tracking

The tracker calls the ```close_now``` block each second and stops whenever the call
returns true. The stop procedure includes an additional timeframe where the tracker
waits for each pending message to be completely processed.

It's up to the developer's responsibility to complete message processing as soon as
possible. After 10 seconds (by default), the stop will be forced and a few messages
already received but not processed yet may be lost.

The ```:stop_timeout``` may be fine-tune when passing options to the tracker.

## Disconnections and Retries

As highly recommended by GNIP, the PowerTrack::Stream client manages an exponential
backoff retry mechanism when a disconnection happens. The reconnections can be
fine-tuned through the ```max_retries``` and ```backoff``` options passed to the
```track``` call.

## Backfill

Backfill is a feature provided by GNIP to avoid losing activities when being
disconnected. It automatically resends the messages sent on the stream for the
last 5 minutes when reconnecting.

Provide a (numerical) client id as the last (but optional) argument of the
PowerTrack::Stream constructor to enable this feature.

## Errors

All the errors that come from PowerTrack are defined through an ad-hoc exception
class hierarchy. See ```lib/powertrack/errors.rb```.

## Credits

The ```powertrack``` gem heavily relies on *EventMachine* and the *em-http-request*
companion gem. It also got inspiration from a few other gems

* The [gnip-rule](https://github.com/singlebrook/gnip-rule) gem
* The [gnip-stream](https://github.com/rweald/gnip-stream) gem
* The [exponential-backoff](https://github.com/pawelpacana/exponential-backoff) gem
