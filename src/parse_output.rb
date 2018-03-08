#regexp=Regexp.new('^([^\n]+) use gradle[^\n]+$^\1 use maven',Regexp::MULTILINE)
regexp=Regexp.new('[^\n]+ use gradle[^\n]+',Regexp::MULTILINE)

f=IO.read('218@3.log')

if f.scan(/Reactor Summary|mvn/m).size >= 2
  print ' use maven'
  puts

end

