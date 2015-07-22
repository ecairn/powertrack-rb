require 'powertrack/rules/rule'

# Extend core String class with a rule transformer
class String
  def to_pwtk_rule(tag=nil, long=nil)
    PowerTrack::Rule.new(self, tag, long)
  end
end
