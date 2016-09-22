gem 'minitest'
require 'minitest/autorun'
require 'yaml'

class Minitest::Test

  POWERTRACK_CONFIG_FILEPATH = File.join(File.dirname(__FILE__), "powertrack.yml")

  # Returns the PowerTrack configuration as defined in test/powertrack.yml.
  def powertrack_config
    unless defined?(@loaded) && @loaded
      begin
        if File.exist?(POWERTRACK_CONFIG_FILEPATH)
          @pwtk_config = (YAML.load_file(POWERTRACK_CONFIG_FILEPATH) || {})
        else
          $stderr.puts "No PowerTrack config file found at '#{POWERTRACK_CONFIG_FILEPATH}'"
        end
      rescue Exception
        $stderr.puts "Exception while loading PowerTrack config file: #{$!.message}"
      ensure
        @pwtk_config ||= {}
      end

      # symbolize keys
      @pwtk_config = Hash[@pwtk_config.map{ |k, v| [k.to_sym, v] }]
      @loaded = true
    end

    @pwtk_config
  end

  # Returns a brand-new stream based on the config found in test/powertrack.yml.
  def new_stream(v2=false, replay=false)
    PowerTrack::Stream.new(
      powertrack_config[:username],
      powertrack_config[:password],
      powertrack_config[:account_name],
      powertrack_config[:data_source],
      replay ? 'prod' : powertrack_config[:stream_label],
      replay: replay,
      v2: v2)
  end
end
