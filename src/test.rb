def test(f)
  f='nihao'
end

f=IO.readlines 'similarityTooLow'
puts f
#test f
f.each do |line|
  line.delete! 'zh'
end
#puts f
a='ni'
b='hao'
c=a+b

p a.object_id
p b.object_id
p c.object_id