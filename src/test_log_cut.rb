require 'set'
MAVEN_ERROR_FLAG='COMPILATION ERROR'
GRADLE_ERROR_FLAG='Compilation failed'



@error_type_number=Hash.new(0)
SEGMENT_BOUNDARY="/home/travis"
@segment_cut_regexp=/(\/[^\n]+){2,}\/\w+[\w\d]*\.java/

def map(output_file,segment_lines)
  segment=segment_lines.join

  puts segment
  puts
  puts
end

def cutSegment(output_file,segment)
  segment_lines=segment.lines
  cut_point=[]
  segment_lines.each_with_index do |line,index|
    next unless @segment_cut_regexp=~line
    cut_point<<index if index!=0
  end
  line_begin=0
  cut_point.each do |point|
    line_end=point
    map(output_file,segment_lines[line_begin...line_end])
    line_begin=line_end
  end
  line_end=segment_lines.length-1
  map(output_file,segment_lines[line_begin..line_end])
end

def gradleCutSegment(log_file_path)
  set=Set.new
  file_lines=IO.readlines(log_file_path).collect!{|line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")}
  file_lines.each_with_index do|line,index|
    next unless Regexp.new(GRADLE_ERROR_FLAG)=~line
    k=index-11
    if line=~/[0-9]+%/
      while k>0 && file_lines[k]!~/(?<!\d)0%/
        k-=1
      end
    else
      if file_lines[index-1]!~/Execution failed for task/
        while k>0 && file_lines[k]!~/:compileTestJava|:compileJava|\.\/gradle/
          k-=1
        end
      else
        match=/.*'(.+)'/.match file_lines[index-1]
        while k>0 && file_lines[k]!~/:compileTestJava|:compileJava|\.\/gradle/ && file_lines[k]!~/^#{match[1]}/
          k-=1
        end
      end
    end
    set.merge((k..index))
  end
  return if set.length==0
  segment=''
  array=set.to_a.sort!
  array.each do |k|
    segment+=file_lines[k] if file_lines[k]!~/Download\s*http/i && file_lines[k]!~/downloaded.*KB\/.*KB/i && file_lines[k]!~/at [.$\w\d]+\([.$\w\d]+:[0-9]+\)/i
  end
  cutSegment('gradleSegment',segment)
end

def mavenCutSegment(log_file_path)
  set=Set.new
  file_lines=IO.readlines(log_file_path).collect!{|line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")}
  file_lines.each_with_index do|line,index|
    next unless Regexp.new(MAVEN_ERROR_FLAG)=~line
    k=index
    while k<file_lines.length && file_lines[k]!~/[0-9]+ error/ && file_lines[k]!~/Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin/
      k+=1
    end
    set.merge((index..k))
  end
  return if set.length==0
  segment=''
  array=set.to_a.sort!
  array.each do |k|
    segment+=file_lines[k] if file_lines[k]!~/Download\s*http/i && file_lines[k]!~/downloaded.*KB\/.*KB/i && file_lines[k]!~/at [.$\w\d]+\([.$\w\d]+:[0-9]+\)/i
  end

  cutSegment('mavenSegment',segment)
end

def mavenOrGradle(log_file_path)
  @error_type_number.clear

  puts "--Scanning file: #{log_file_path}"
  file=IO.read(log_file_path).gsub(/\r\n?/, "\n")
  if file.scan(/gradle/i).size >= 2
    print '>>>>>>>>>>>>>>>>>>>>>>>>>',' USE Gradle'
    puts
    gradleCutSegment(log_file_path)
  end

  if file.scan(/Reactor Summary|mvn/i).size >= 2
    print '>>>>>>>>>>>>>>>>>>>>>>>>>',' USE Maven'
    puts
    mavenCutSegment(log_file_path)
  end

end
mavenOrGradle('1070@2.log')