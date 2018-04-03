require 'set'
require_relative 'property'
require 'csv'


MAVEN_ERROR_FLAG='COMPILATION ERROR'
GRADLE_ERROR_FLAG='Compilation failed'
GRADLE_ERROR_UP_BOUNDARY=/:compileTestJava|:compileJava|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala|\.\/gradle|travis_time/

SEGMENT_BOUNDARY="/home/travis"
SEGMENT_BOUNDARY_FILE=/(\/[^\n\/]+){2,}\/\w+[\w\d]*\.(java|groovy|scala|kt|sig)/
SEGMENT_BOUNDARY_JAVA=/(\/[^\n\/]+){2,}\/\w+[\w\d]*\.java/
SEGMENT_BOUNDARY_GROOVY=/(\/[^\n\/]+){2,}\/\w+[\w\d]*\.groovy/
SEGMENT_BOUNDARY_SCALA=/(\/[^\n\/]+){2,}\/\w+[\w\d]*\.scala/
SEGMENT_BOUNDARY_KOTLIN=/(\/[^\n\/]+){2,}\/\w+[\w\d]*\.kt/
SEGMENT_BOUNDARY_SIG=/(\/[^\n\/]+){2,}\/\w+[\w\d]*\.sig/
SEGMENT_BOUNDARY_JAR=/(\/[^\n\/]+){2,}\/\w+[-\w\d]*\.jar/


@regex_hash=Property.new.getRegexpHash

#@error_type_number=Hash.new(0)

def calculateWordNumberSimilarity(segment,regex)
  word_array_a=regex.source.lines[0].scan(/\w{2,}/)
  first_line=segment.lines[0]

  count_a=0
  word_array_a.each do |word|
    count_a+=1 if first_line.include?(word)
  end
  similarity_a=count_a.to_f/word_array_a.length

  word_array_b=regex.source.scan(/\w{2,}/)
  count_b=0
  word_array_b.each do |word|
    count_b+=1 if segment.include?(word)
  end
  similarity_b=count_b.to_f/word_array_b.length

  similarity_div=similarity_a*0.8+similarity_b*0.2
  similarity=similarity_div*0.8+word_array_b.length.to_f/30*0.2
end

def getLargestSimilarity(hash)
  max=hash.keys[0]
  hash.each do |key,value|
    max=key if value>hash[max]
  end
  max
end

def map(log_file_path,output_file,segment_lines)
  output_file+='map'
  segment=segment_lines.join
  match_length_similarity=Hash.new(0)
  word_number_similarity=Hash.new(0)

  @regex_hash.each do |key,regex|
    word_number_similarity[key]=calculateWordNumberSimilarity(segment,regex)
    match=regex.match(segment)
    next unless match
    if match[0]==segment
      File.open(output_file,'a') do |output|
        output.puts
        output.puts '====================================='
        output.puts "In file #{log_file_path}:"
        output.puts "The matching regexp is: key=#{key}  regexp=#{regex.source}"
        output.puts "The matched segment is:"
        output.puts segment
        output.puts
      end
      #@error_type_number[key]+=1
      return
    end
    match_length_similarity[key]=match[0].length.to_f/segment.length
  end
  key_word_number_similarity=getLargestSimilarity(word_number_similarity)
  key_match_length_similarity=match_length_similarity.length!=0 ? getLargestSimilarity(match_length_similarity) : nil

  File.open(output_file,'a') do |output|
    output.puts
    output.puts '====================================='
    output.puts "In file #{log_file_path}:"
    output.puts "The matched segment is:"
    output.puts segment
    output.puts
    output.puts "According to the match_length_similarity, matching regexp is: key=#{key_match_length_similarity}  regexp=#{@regex_hash[key_match_length_similarity]}   similarity=#{key_match_length_similarity.nil? ? 0 : match_length_similarity[key_match_length_similarity]}"
    output.puts "The matched part is:"
    match=key_match_length_similarity.nil? ? nil : @regex_hash[key_match_length_similarity].match(segment)
    output.puts match[0] if match
    output.puts 'NULL' unless match
    match=@regex_hash[key_word_number_similarity].match(segment)
    output.puts
    output.puts "According to the word_number_similarity, matching regexp is: key=#{key_word_number_similarity}  regexp=#{@regex_hash[key_word_number_similarity]}   similarity=#{word_number_similarity[key_word_number_similarity]}"
    output.puts "The matched part is:"
    output.puts match[0] if match
    output.puts 'NULL'   unless match
    output.puts
  end

  return if word_number_similarity[key_word_number_similarity]>0.3

  File.open('similarityTooLow','a') do |output|
    output.puts 'zhangchen>>>>>>>>>>>>>>>>>>>>>>>>>'
    output.puts segment
    output.puts
  end
end

def cutSegment(log_file_path,output_file,segment)
  segment_lines=segment.lines
  cut_point=[]
  segment_lines.each_with_index do |line,index|
    next unless SEGMENT_BOUNDARY_FILE=~line || SEGMENT_BOUNDARY_JAR=~line
    cut_point<<index if index!=0
  end

  cut_range=[]
  line_begin=0
  cut_point.each do |point|
    line_end=point
    cut_range<<(line_begin...line_end)
    line_begin=line_end
  end
  cut_range<<(line_begin..(segment_lines.length-1))

  File.open(output_file,'a') do |output|
    output.puts
    output.puts "Segment in #{log_file_path} is:"
    output.puts segment
    output.puts
    cut_range.each_with_index do |r,index|
      output.puts "Part #{index}---->"
      output.puts segment_lines[r]
      output.puts
    end
  end

  cut_range.each do |r|
    #map(output_file,segment_lines[r]) if segment_lines[r.begin]=~SEGMENT_BOUNDARY_JAVA || segment_lines[r.begin]=~SEGMENT_BOUNDARY_JAR
    map(log_file_path,output_file,segment_lines[r]) if segment_lines[r.begin]!~SEGMENT_BOUNDARY_GROOVY && segment_lines[r.begin]!~SEGMENT_BOUNDARY_SCALA && segment_lines[r.begin]!~SEGMENT_BOUNDARY_KOTLIN
  end
end

def addLine?(line)
  flag=true
  flag=false if line=~/Download\s*http/i
  flag=false if line=~/downloaded.*KB\/.*KB/i
  flag=false if line=~/at [.$\w\d]+\([-@.$\/\w\d]+:[0-9]+\)/i
  flag=false if line=~/at [.\w\d]+\/[.\w\d]+\([.: \w\d]+\)/i
  flag=false if line=~/^$/
  flag=false if line=~/-{10,}/
  flag=false if line=~/COMPILATION ERROR/
  flag=false if line=~/[0-9]+ (error|errors)[\s&&[^\n]]*$/
  flag=false if line=~/[0-9]+ (warning|warnings)[\s&&[^\n]]*$/
  flag=false if line=~/^Note:/
  flag=false if line=~/What went wrong/
  flag=false if line=~/Build failed with an exception/
  flag=false if line=~/Execution failed for task/
  flag=false if line=~/Compilation failed/
  flag=false if line=~/FAILED$/
  flag=false if line=~/^\[info\]/
  flag=false if line=~/Failed to execute goal/
  flag=false if line=~/(:compileTestJava|:compileJava|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala)$/
  flag=false if line=~/warnings found and -Werror specified/
  flag
end

def gradleCutSegment(log_file_path)

  set=Set.new
  file_lines=IO.readlines(log_file_path).collect!{|line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")}
  file_lines.each_with_index do|line,index|
    next unless Regexp.new(GRADLE_ERROR_FLAG)=~line
    k=index-7

    if file_lines[index-1]!~/Execution failed for task/
      while k>0 && file_lines[k]!~GRADLE_ERROR_UP_BOUNDARY && file_lines[k]!~/(?<!\d)0%/
        k-=1
      end
    else
      match=/.*'(.+)'/.match file_lines[index-1]
      while k>0 && file_lines[k]!~GRADLE_ERROR_UP_BOUNDARY && file_lines[k]!~/^#{match[1]}/ && file_lines[k]!~/(?<!\d)0%/
        k-=1
      end
    end

    set.merge((k..index))
  end
  return if set.length==0
  segment=''
  array=set.to_a.sort!
  array.each do |k|
    segment+=file_lines[k] if addLine?(file_lines[k])
  end
  cutSegment(log_file_path,'gradleSegment',segment)
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
    segment+=file_lines[k] if addLine?(file_lines[k])
  end

  cutSegment(log_file_path,'mavenSegment',segment)
end

def mavenOrGradle(log_file_path)
  file=IO.read(log_file_path).gsub(/\r\n?/, "\n")
  if file.scan(/gradle/i).size >= 2
    print '>>>>>>>>>>>>>>>>>>>>>>>>>',log_file_path,' USE Gradle'
    puts
    gradleCutSegment(log_file_path)
  end

  if file.scan(/Reactor Summary|mvn/i).size >= 2
    print '>>>>>>>>>>>>>>>>>>>>>>>>>',log_file_path,' USE Maven'
    puts
    mavenCutSegment(log_file_path)
  end

end

def traverseDir(build_logs_path)
  threads=[]
  count=0
  Dir.entries(build_logs_path).delete_if {|repo_name| /.+@.+/!~repo_name}.each do |repo_name|
    count+=1
    next if count<30

    repo_path=File.join(build_logs_path,repo_name)
    puts "Scanning projects: #{repo_path}"
    Dir.entries(repo_path).delete_if {|log_file_name| /.+@.+/!~log_file_name}.sort_by!{|e| e.sub(/\.log/,'').sub(/@/,'.').to_f}.each do |log_file_name|
      log_file_path=File.join(repo_path,log_file_name)
      puts "--Scanning file: #{log_file_path}"

      thr=Thread.new(log_file_path) do |p|
        mavenOrGradle(p)
      end
      threads<<thr

      loop do
        count=Thread.list.count{|thread| thread.alive? }
        break if count <= 20
      end
      threads.delete_if{|thread| !thread.alive?}
    end
  end

  threads.each do |thread|
    thread.join if thread.alive?
  end
end

Thread.abort_on_exception = true
build_logs_path=ARGV[0]||'../../bodyLog2/build_logs/'
traverseDir(build_logs_path)