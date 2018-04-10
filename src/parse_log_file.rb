require 'set'
require_relative 'property'
require 'csv'


MAVEN_ERROR_FLAG = /COMPILATION ERROR/
GRADLE_ERROR_FLAG = /Compilation failed/
GRADLE_ERROR_UP_BOUNDARY = /:compileTestJava|:compileJava|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala|\.\/gradle|travis_time/

SEGMENT_BOUNDARY = "/home/travis"
SEGMENT_BOUNDARY_FILE = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.(java|groovy|scala|kt|sig)/
SEGMENT_BOUNDARY_JAVA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.java/
SEGMENT_BOUNDARY_GROOVY = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.groovy/
SEGMENT_BOUNDARY_SCALA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.scala/
SEGMENT_BOUNDARY_KOTLIN = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.kt/
SEGMENT_BOUNDARY_SIG = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.sig/
SEGMENT_BOUNDARY_JAR = /(\/[^\n\/]+){2,}\/\w+[-\w\d]*\.jar/


@regex_hash = Property.new.getRegexpHash

#@error_type_number=Hash.new(0)

def word_number_similarity(segment, regex)
  word_array_a = regex.source.lines[0].scan(/\w{2,}/)
  first_line = segment.lines[0]

  count_a = 0
  word_array_a.each do |word|
    count_a += 1 if first_line.include?(word)
  end
  similarity_a = count_a.to_f / word_array_a.length

  word_array_b = regex.source.scan(/\w{2,}/)
  count_b = 0
  word_array_b.each do |word|
    count_b += 1 if segment.include?(word)
  end
  similarity_b = count_b.to_f / word_array_b.length

  similarity_div = similarity_a * 0.8 + similarity_b * 0.2
  similarity = similarity_div * 0.8 + word_array_b.length.to_f / 30 * 0.2
end

def map(log_file_path, output_file,segment)
  output_file += 'map'
  max_value_word_number = 0
  max_value_match_length = 0
  key_word_number = nil
  key_match_length = nil
  @regex_hash.each do |key, regex|
    value_word_number = word_number_similarity(segment, regex)

    if value_word_number > max_value_word_number
      max_value_word_number = value_word_number
      key_word_number = key
    end

    match = regex.match(segment)
    next unless match
    if match[0] == segment
      File.open(output_file, 'a') do |output|
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
    value_match_length = match[0].length.to_f / segment.length
    if value_match_length > max_value_match_length
      max_value_match_length = value_match_length
      key_match_length = key
    end
  end

  File.open(output_file, 'a') do |output|
    output.puts
    output.puts '====================================='
    output.puts "In file #{log_file_path}:"
    output.puts "The matched segment is:"
    output.puts segment
    output.puts
    output.puts "According to the match_length_similarity, matching regexp is: key=#{key_match_length}  regexp=#{@regex_hash[key_match_length]}   similarity=#{max_value_match_length}"
    output.puts "The matched part is:"
    match=key_match_length.nil? ? nil : @regex_hash[key_match_length].match(segment)
    output.puts match[0] if match
    output.puts 'NULL' unless match
    match=@regex_hash[key_word_number].match(segment)
    output.puts
    output.puts "According to the word_number_similarity, matching regexp is: key=#{key_word_number}  regexp=#{@regex_hash[key_word_number]}   similarity=#{max_value_word_number}"
    output.puts "The matched part is:"
    output.puts match[0] if match
    output.puts 'NULL'   unless match
    output.puts
  end

  return if max_value_word_number > 0.3

  File.open('similarityTooLow', 'a') do |output|
    output.puts 'zhangchen>>>>>>>>>>>>>>>>>>>>>>>>>'
    output.puts segment
    output.puts
  end
end

def cut_segment(log_file_path, output_file, segment_lines)
  cut_point = []
  segment_lines.each_with_index do |line, index|
    next unless SEGMENT_BOUNDARY_FILE =~ line || SEGMENT_BOUNDARY_JAR =~ line
    cut_point<<index if index != 0
  end

  cut_range=[]
  begin_number=0
  cut_point.each do |point|
    end_number=point
    cut_range << (begin_number...end_number)
    begin_number = end_number
  end
  cut_range << (begin_number..(segment_lines.length - 1))

  File.open(output_file, 'a') do |output|
    output.puts
    output.puts "Segment in #{log_file_path} is:"
    output.puts segment_lines
    output.puts
    cut_range.each_with_index do |r,index|
      output.puts "Part #{index}---->"
      output.puts segment_lines[r]
      output.puts
    end
  end

  cut_range.each do |r|
    #map(output_file,segment_lines[r]) if segment_lines[r.begin]=~SEGMENT_BOUNDARY_JAVA || segment_lines[r.begin]=~SEGMENT_BOUNDARY_JAR
    map(log_file_path,output_file,segment_lines[r].join) if segment_lines[r.begin] !~ SEGMENT_BOUNDARY_GROOVY && segment_lines[r.begin] !~ SEGMENT_BOUNDARY_SCALA && segment_lines[r.begin] !~ SEGMENT_BOUNDARY_KOTLIN
  end
end

def add_line?(line)
  flag = true
  flag = false if line =~ /Download\s*http/i
  flag = false if line =~ /downloaded.*KB\/.*KB/i
  flag = false if line =~ /at [.$\w\d]+\([-@.$\/\w\d]+:[0-9]+\)/i
  flag = false if line =~ /at [.\w\d]+\/[.\w\d]+\([.: \w\d]+\)/i
  flag = false if line =~ /at [.$\w\d]+\(Native Method\)/i
  flag = false if line =~ /^$/
  flag = false if line =~ /-{10,}/
  flag = false if line =~ /COMPILATION ERROR/
  flag = false if line =~ /[0-9]+ (error|errors)[\s&&[^\n]]*$/
  flag = false if line =~ /[0-9]+ (warning|warnings)[\s&&[^\n]]*$/
  flag = false if line =~ /^Note:/

  flag = false if line =~ /Failed to execute goal/
  flag = false if line =~ /What went wrong/
  flag = false if line =~ /Build failed with an exception/
  flag = false if line =~ /Execution failed for task/
  flag = false if line =~ /Compilation failed/
  flag = false if line =~ /FAILED$/
  flag = false if line =~ /^\[info\]/
  flag = false if line =~ /(:compileTestJava|:compileJava|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala)$/
  flag = false if line =~ /warnings found and -Werror specified/
  flag = false if line =~ /UP-TO-DATE/
  flag = false if line =~ /FROM-CACHE/
  flag = false if line =~ /NO-SOURCE/
  flag = false if line =~ /SKIPPED/
  flag = false if line =~ /:[a-zA-Z]+:[a-zA-Z]+$/
  flag
end

def cut_gradle(log_file_path, file_lines)
  set = Set.new
  file_lines.each_with_index do |line,end_number|
    next unless GRADLE_ERROR_FLAG =~ line
    begin_number = end_number - 7

    if file_lines[end_number-1]!~/Execution failed for task/
      while begin_number > 0 && file_lines[begin_number] !~ GRADLE_ERROR_UP_BOUNDARY && file_lines[begin_number] !~ /(?<!\d)0%/
        begin_number -= 1
      end
    else
      match = /.*'(.+)'/.match file_lines[end_number-1]
      while begin_number > 0 && file_lines[begin_number] !~ GRADLE_ERROR_UP_BOUNDARY && file_lines[begin_number] !~ /^#{match[1]}/ && file_lines[begin_number] !~ /(?<!\d)0%/
        begin_number -= 1
      end
    end

    set.merge (begin_number..end_number)
  end
  segment_lines = []
  array = set.to_a.sort!
  array.each do |k|
    segment_lines << file_lines[k] if add_line? file_lines[k]
  end
  return if segment_lines.length == 0

  cut_segment(log_file_path, 'gradleSegment', segment_lines)
end


def cut_maven(log_file_path, file_lines)
  set = Set.new
  file_lines.each_with_index do |line, begin_number|
    next unless MAVEN_ERROR_FLAG =~ line
    end_number = begin_number
    while end_number < file_lines.length && file_lines[end_number] !~ /[0-9]+ error|Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin/
      end_number += 1
    end
    set.merge (begin_number..end_number)
  end
  segment_lines = []
  array = set.to_a.sort!
  array.each do |k|
    segment_lines << file_lines[k] if add_line? file_lines[k]
  end
  return if segment_lines.length == 0

  cut_segment(log_file_path, 'mavenSegment', segment_lines)
end

def use_build_tool?(log_file_path)
  begin
    file_lines = IO.readlines(log_file_path).collect!{ |line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n") }
  rescue
    file_lines = IO.readlines(log_file_path, :encoding => 'ISO-8859-1').collect!{ |line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n") }
  end
  count_maven = 0
  count_gradle = 0
  file_lines.each do |line|
    count_maven += 1 if line.include?('mvn') || line.include?('Reactor Summary')
    count_gradle += 1 if line.include?('gradle')
  end
  cut_maven(log_file_path, file_lines) if count_maven >= 2
  cut_gradle(log_file_path, file_lines) if count_gradle >= 2
end

def scan_log_directory(build_logs_path)
  #flag = true
  Dir.foreach(build_logs_path) do |repo_name|
    next if /.+@.+/ !~ repo_name
    #flag = false if repo_name.include? 'selenium'
    #next if flag
    repo_path = File.join(build_logs_path, repo_name)
    puts "Scanning projects: #{repo_path}"

    Dir.foreach(repo_path) do |log_file_name|
      next if /.+@.+/ !~ log_file_name
      log_file_path = File.join(repo_path, log_file_name)
      puts "--Scanning file: #{log_file_path}"
      Thread.new(log_file_path) do |p|
        use_build_tool? p
      end
      loop do
        break if Thread.list.count{ |thread| thread.alive? } <= 50
      end
    end
  end
  Thread.list.each{ |thread| thread.join if thread.alive? && thread != Thread.current}
end

Thread.abort_on_exception = true
build_logs_path = ARGV[0]||'../../bodyLog2/build_logs/'
scan_log_directory build_logs_path