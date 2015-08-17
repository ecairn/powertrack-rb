# See http://stackoverflow.com/questions/2393697/look-up-all-descendants-of-a-class-in-ruby
class Class
  # Returns the descendants of the class.
  def descendants
    ObjectSpace.each_object(::Class).select {|klass| klass < self }
  end
end
