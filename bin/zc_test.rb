require 'temp_compilation_slice'
temp = TempCompilationSlice.find_by(id: 2)
temp.maven_slice.each do |i|
  lines = i.lines
  lines.collect! { |l| l.gsub(/\r\n/, "\n")  }
  hash = Hash.new
  hash[:id] = 3
  array = []
  array <<  lines.join
  hash[:maven_slice] = array
  TempCompilationSlice.create hash
end