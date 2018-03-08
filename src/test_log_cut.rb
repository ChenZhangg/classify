require 'set'
@maven_error_message='COMPILATION ERROR'
@gradle_error_message='Compilation failed'
def mavenOrGradle(file)
  puts file
  f=IO.read(file)
  if f.scan(/gradle/im).size >= 2
    print file,' use gradle'
    puts
    gradleCutSegment(file)
  end

  if f.scan(/Reactor Summary|mvn/im).size >= 2
    print file,' use maven'
    puts
    mavenCutSegment(file)
  end

rescue
  puts "ERROR HAPPENED in #{file}"
  puts $!
end

def gradleCutSegment(file)
  set=Set.new
  f=IO.readlines(file)
  f.each_with_index do|line,index|
    next unless Regexp.new(@gradle_error_message)=~line
    k=index-11
    if line=~/[0-9]+%/
      while k>0 && f[k]!~/(?<!\d)0%/
        k-=1
      end
    else
      if f[index-1]!~/Execution failed for task/
        while k>0 && f[k]!~/:compileTestJava|:compileJava|\.\/gradle/
          k-=1
        end
      else
        /.*'(.+)'/=~f[index-1]
        while k>0 && f[k]!~/:compileTestJava|:compileJava|\.\/gradle/ && [k]!~/^#{$1}/
          k-=1
        end
      end
    end
    set.merge((k..index))
  end
  return if set.size==0
  segment=''
  array=set.to_a.sort!
  array.each do |k|
    puts f[k] if  /downloaded.*KB\/.*KB/ !~ f[k]
    puts
    puts
  end
  #puts segment
  File.open('gradleSegment','a') do |output|
    output.puts
    output.puts file
    output.puts segment
    output.puts
  end
end
