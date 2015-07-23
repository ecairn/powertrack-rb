# See http://stackoverflow.com/questions/2393697/look-up-all-descendants-of-a-class-in-ruby
class Class
  def descendants
    ObjectSpace.each_object(::Class).select {|klass| klass < self }
  end
end
