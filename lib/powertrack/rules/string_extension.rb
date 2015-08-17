require 'powertrack/rules/rule'

# Extend core String class with a rule transformer
class String
  # Returns a PowerTrace::Rule instance based on the value of the string.
  def to_pwtk_rule(tag=nil, long=nil)
    PowerTrack::Rule.new(self, tag, long)
  end
end
