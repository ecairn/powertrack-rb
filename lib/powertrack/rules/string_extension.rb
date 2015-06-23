require 'powertrack/rules/rule'

# Extend core String class with a rule transformer
class String
  def to_pwtk_rule(long=false, tag=nil)
    PowerTrack::Rule.new(self, long, tag)
  end
end
