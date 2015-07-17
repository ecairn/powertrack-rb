## General

* _[DONE]_ Rely upon MultiJson for JSON encoding and decoding

## Rules

* _[DONE]_ Check rule size
* Rule encoding (UTF-8 enforcement ?)
* Check all [advanced restrictions](http://support.gnip.com/apis/powertrack/rules.html#Restrictions) on rules
* Add 1 or more rules to a stream
* Delete some rules from the stream
* Get all existing rules for a stream
* Double check a rule supports all the syntactical and semantic restrictions
  as defined by GNIP [PowerTrack Rules](http://support.gnip.com/apis/powertrack/rules.html)
  reference documentation
* _[MAYBE]_ Support evolution of rules in terms of addition, removal and updates.

## Real-time powertrack

* Manage persitent connection to a data stream. See
  [Powertrack API reference](http://support.gnip.com/apis/powertrack/api_reference.html)
* Reconnect after disconnect. See
  [Disconnections & Reconnecting](http://support.gnip.com/apis/consuming_streaming_data.html#Disconnections)
* Reconnect using an exponential backoof pattern when there's a GNIP server issue
  signaled by the 503 HTTP response status
* [Consume streaming data](http://support.gnip.com/apis/consuming_streaming_data.html)

## Compliance activities

See [Honoring user intent on Twitter](http://support.gnip.com/articles/honoring-user-intent-on-twitter.html)
and [Compliance Activities](http://support.gnip.com/sources/twitter/data_format.html#ComplianceActivities).

### Account

* Protect/Unprotect account
* Delete account
* Scrub geo
* Suspend account
* Withhold account

### Status

* Delete status
* Withhold status

## Data formats

See [Data format](http://support.gnip.com/sources/twitter/data_format.html)

* Support Original output format
* Support Activity Stream output format
* Manage retweets. See [Identifying and Understanding retweets](http://support.gnip.com/articles/identifying-and-understanding-retweets.html)
  * Support official retweets
  * Support quoted tweets
  * Support non-official retweets ?

## Disconnections

See [Managing disconnections](http://support.gnip.com/articles/disconnections-explained.html)

* Support Replay
* Support Backfill

## Other features

* Support test and development streams
* Support status dashboard
* Support Historical Powertrack
