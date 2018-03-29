require 'set'
require_relative 'property'
require 'csv'
@maven_error_message='COMPILATION ERROR'
@gradle_error_message='Compilation failed'
@segment_cut="/home/travis"
@segment_cut_regexp_file=/(\/[^\n\/]+){2,}\/\w+[\w\d]*\.(java|groovy|scala|kt)/
@segment_cut_regexp_jar=/(\/[^\n\/]+){2,}\/\w+[-\w\d.]*\.jar/

@regex_hash=Property.new.getRegexpHash

@error_type_number=Hash.new(0)

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

def map(output_file,segment_lines)
  segment=segment_lines.join
  
  match_length_similarity=Hash.new(0)
  word_number_similarity=Hash.new(0)
  @regex_hash.each do |key,regex|
    puts "key=#{key}  regexp=#{regex.source}"
    puts segment
    word_number_similarity[key]=calculateWordNumberSimilarity(segment,regex)
    match=regex.match(segment)
    next unless match
    if match[0]==segment
      File.open(output_file,'a') do |output|
        output.puts
        output.puts "The matching regexp is: key=#{key}  regexp=#{regex.source}"
        output.puts "The matched segment is:"
        output.puts segment
        output.puts
      end
      @error_type_number[key]+=1
      return
    end
    match_length_similarity[key]=match[0].length.to_f/segment.length
  end
  key_word_number_similarity=getLargestSimilarity(word_number_similarity)

  if match_length_similarity.length!=0
    key_match_length_similarity=getLargestSimilarity(match_length_similarity)
    match=@regex_hash[key_match_length_similarity].match(segment)
    File.open(output_file,'a') do |output|
      output.puts
      output.puts "The matched segment is:"
      output.puts segment
      output.puts
      output.puts "According to the match_length_similarity, matching regexp is: key=#{key_match_length_similarity}  regexp=#{@regex_hash[key_match_length_similarity]}   similarity=#{match_length_similarity[key_match_length_similarity]}"
      output.puts "The matched part is:"
      output.puts match[0]
      output.puts
    end
  else
    File.open(output_file,'a') do |output|
      output.puts
      output.puts "The matched segment is:"
      output.puts segment
      output.puts
      output.puts "According to the match_length_similarity, didn't find regexp that can match the segment"
      output.puts 'NULL'
      output.puts
    end
  end

  match=@regex_hash[key_word_number_similarity].match(segment)
  @error_type_number[key_word_number_similarity]+=1
  File.open(output_file,'a') do |output|
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

def cutSegment(output_file,segment)
  segment_lines=segment.lines
  cut_point=[]
  segment_lines.each_with_index do |line,index|
    next unless @segment_cut_regexp_file=~line
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

def addLine?(line)
  flag=true
  flag=false if line=~/Download\s*http/i
  flag=false if line=~/downloaded.*KB\/.*KB/i
  flag=false if line=~/at [.$\w\d]+\([.$\w\d]+:[0-9]+\)/i
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

  flag
end

def gradleCutSegment(log_file_path)
  set=Set.new
  file_lines=IO.readlines(log_file_path).collect!{|line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")}
  file_lines.each_with_index do|line,index|
    next unless Regexp.new(@gradle_error_message)=~line
    k=index-11
    if line=~/[0-9]+%/
      while k>0 && file_lines[k]!~/(?<!\d)0%/
        k-=1
      end
    else
      if file_lines[index-1]!~/Execution failed for task/
        while k>0 && file_lines[k]!~/:compileTestJava|:compileJava|\.\/gradle|travis_time/
          k-=1
        end
      else
        match=/.*'(.+)'/.match file_lines[index-1]
        while k>0 && file_lines[k]!~/:compileTestJava|:compileJava|\.\/gradle|travis_time/ && file_lines[k]!~/^#{match[1]}/
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
    segment+=file_lines[k] if addLine?(file_lines[k])
  end
  File.open('gradleSegment','a') do |output|
    output.puts
    output.puts "Segment in #{log_file_path} is:"
    output.puts segment
    output.puts
  end

  cutSegment('gradleSegment',segment)
end

def mavenCutSegment(log_file_path)
  set=Set.new
  file_lines=IO.readlines(log_file_path).collect!{|line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")}
  file_lines.each_with_index do|line,index|
    next unless Regexp.new(@maven_error_message)=~line
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
  File.open('mavenSegment','a') do |output|
    output.puts
    output.puts "Segment in #{log_file_path} is:"
    output.puts segment
    output.puts
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

  File.open('statistics.csv','a') do |output|
    CSV(output) do |csv|
      array=[]
      array<<log_file_path
      @error_type_number.each do |key,value|
        array<<"#{key}:#{value}"
      end
      csv<< array
    end
  end
end

def traverseDir(build_logs_path)
  count=0
  (Dir.entries(build_logs_path)).delete_if {|repo_name| /.+@.+/!~repo_name}.each do |repo_name|
    count+=1
    next if count<15
    repo_path=File.join(build_logs_path,repo_name)
    puts "Scanning projects: #{repo_path}"
    Dir.entries(repo_path).delete_if {|log_file_name| /.+@.+/!~log_file_name}.sort_by!{|e| e.sub(/\.log/,'').sub(/@/,'.').to_f}.each do |log_file_name|
      log_file_path=File.join(repo_path,log_file_name)
      mavenOrGradle(log_file_path)
    end
  end
end

@build_logs_path='../../bodyLog2/build_logs/'
traverseDir(@build_logs_path)