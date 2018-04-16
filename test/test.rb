threads = []
Thread.list.each{ |thread| threads << thread }
thr = Thread.new do

end
p thr
p threads