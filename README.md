# powertrack
A Ruby gem for building GNIP PowerTrack streaming clients.

Require Ruby 2.3 or above.

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

The ```:stop_timeout``` may be fine-tuned when passing options to the tracker.

## Disconnections and Retries

As highly recommended by GNIP, the PowerTrack::Stream client manages an exponential
backoff retry mechanism when a disconnection happens. The reconnections can be
fine-tuned through the ```:max_retries``` and ```:backoff``` options passed to
the ```track``` call.

Note that the retries counter is reset each time the client manages to receive
a message after a disconnection except in Replay mode (see further).

## Backfill

Backfill is a feature provided by GNIP to avoid losing activities when being
disconnected. It automatically resends the messages sent on the stream for the
last 5 minutes when reconnecting.

Provide a (numerical) client id by setting the ```:client_id``` option when
building a ```PowerTrack::Stream``` object to enable this feature.

## Replay

Replay is a feature provided by GNIP to recover lost activities over the last
5 days. The Replay stream lives aside the realtime stream and is activated
by setting the ```:replay``` option to ```true``` when building a ```PowerTrack::Stream```
object.

Once Replay is activated, you use the stream as previously, starting by
configuring some rules that define which activities you will recover. Once done,
you can track the stream by specifying a timeframe with the ```:from```
and ```:to``` options. By default, replay happens over 30 minutes, starting 1
hour ago.

Regarding Replay mode and ```:max_retries```, the client does not reset the
retry counter and will never reconnect more than the max number of retries
specified. This specific retry behavior in Replay mode prevents the client from
replaying the same timeframe again and again when GNIP is unstable.

## Errors

All the errors that come from PowerTrack are defined through an ad-hoc exception
class hierarchy. See ```lib/powertrack/errors.rb```.

## PowerTrack v1

The library was originally designed for PowerTrack v1. But this version of the
PowerTrack API was sunset in early January 2017.

Consequently, since v2.0, the library does not support v1 anymore.

## PowerTrack v2

The library provides support for PowerTrack API version 2. Please read
[PowerTrack API v2](http://support.gnip.com/apis/powertrack2.0/index.html) and
the [Migration Guide](http://support.gnip.com/apis/powertrack2.0/transition.html)
for details about this new major release.

Everything should work the same for v2 as for v1 except

o ```PowerTrack::Stream.add_rule``` and ```PowerTrack::Stream.delete_rule```
  returns a status instead of nil
o The Backfill feature is configured by the ```:backfill_minutes``` option passed
  to the ```PowerTrack::Stream.track``` method instead of passing a ```:client_id```
  option to the ```PowerTrack::Stream``` initializer (which is simply ignored
  when v2 is turned on). The new option specifies a number of minutes of backfill
  data to receive.
o A v2 ```PowerTrack::Rule``` instance (initialized by passing the ```v2: true```
  feature to the constructor) has a few specificities described in
  [Migrating PowerTrack Rules from Version 1.0 to 2.0](http://support.gnip.com/articles/migrating-powertrack-rules.html).

  In particular,
  o it is always long (accepting up to 2048 characters),
  o it has no limits on the number of positive or negative terms used,
  o it forbids the usage of *AND*, *or* and *NOT* logical phrases.

Finally, PowerTrack v2 has a new endpoint for rule validation that is not
supported by this library yet.

## Credits

The ```powertrack``` gem heavily relies on *EventMachine* and the *em-http-request*
companion gem. It also got inspiration from a few other gems

* The [gnip-rule](https://github.com/singlebrook/gnip-rule) gem
* The [gnip-stream](https://github.com/rweald/gnip-stream) gem
* The [exponential-backoff](https://github.com/pawelpacana/exponential-backoff) gem
