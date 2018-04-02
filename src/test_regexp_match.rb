require_relative 'property'
require 'set'
a=[]
b=('a'..'z').to_a
a<<(5...10)
puts b[a[0]]
puts b.class
puts a[0].class
puts a[0].begin
puts a[0].begin.class
