require 'set'
require 'fdse/property'
require 'csv'
require 'elif'
require 'fileutils'
require 'thread'

module Fdse
  class ParseLogFile
    MAVEN_ERROR_FLAG = /COMPILATION ERROR/
    GRADLE_ERROR_FLAG = /> Compilation failed; see the compiler error output for details/
    GRADLE_ERROR_UP_BOUNDARY = /:compileTestJava|:compileJava|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala|\.\/gradle|travis_time/
    SEGMENT_BOUNDARY = "/home/travis"
    SEGMENT_BOUNDARY_FILE = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.(java|groovy|scala|kt|sig)/
    SEGMENT_BOUNDARY_JAVA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.java/
    SEGMENT_BOUNDARY_GROOVY = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.groovy/
    SEGMENT_BOUNDARY_SCALA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.scala/
    SEGMENT_BOUNDARY_KOTLIN = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.kt/
    SEGMENT_BOUNDARY_SIG = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.sig/
    SEGMENT_BOUNDARY_JAR = /(\/[^\n\/]+){2,}\/\w+[-\w\d]*\.jar/
    @regex_hash = Fdse::Property.new.run

    def self.word_number_similarity(segment, regex)
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

    def self.map(segment)
      match_key = nil
      max_value_word_number = 0
      @regex_hash.each do |key, regex|
        value_word_number = word_number_similarity(segment, regex)
        if value_word_number > max_value_word_number
          max_value_word_number = value_word_number
          match_key = key
        end
        match = regex.match(segment)
        if match && match[0] == segment
          match_key = key
          max_value_word_number = 1
          break
        end
      end
      [match_key, max_value_word_number]
    end

    def self.segment_slice(segment_lines)
      slice_point = []
      segment_lines.each_with_index do |line, index|
        next unless SEGMENT_BOUNDARY_FILE =~ line || SEGMENT_BOUNDARY_JAR =~ line
        slice_point << index if index != 0
      end

      slice_range=[]
      begin_number=0
      slice_point.each do |point|
        end_number=point
        slice_range << (begin_number...end_number)
        begin_number = end_number
      end
      slice_range << (begin_number..(segment_lines.length - 1))

      segment_array = []
      slice_range.each do |range|
        segment_array << segment_lines[range].join if segment_lines[range.begin] !~ SEGMENT_BOUNDARY_GROOVY && segment_lines[range.begin] !~ SEGMENT_BOUNDARY_SCALA && segment_lines[range.begin] !~ SEGMENT_BOUNDARY_KOTLIN
      end
      segment_array
    end

    def self.line_validate?(line)
      flag = true
      flag = false if line.nil?
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

    def self.gradle_slice(log_file_path)
      array = []
      flag = false
      count = 7
      regexp = /zhang chen/
      Elif.foreach(log_file_path) do |line|
        begin
          temp_line = line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
        rescue
          temp_line = line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
        end
        if GRADLE_ERROR_FLAG =~ temp_line
          flag = true
          count = 7
        end
        if flag && count == 6
          match = /Execution failed for task '(.+)'/.match(line)
          regexp = /^#{match[1]}/ if match
        end
        array.unshift(temp_line) if flag && line_validate?(temp_line)
        if flag && count <=0 && (temp_line =~ GRADLE_ERROR_UP_BOUNDARY || temp_line =~ regexp || temp_line =~ /(?<!\d)0%/)
          flag = false
        end
        count -= 1
      end
      array
    end

    def self.maven_slice(log_file_path)
      array = []
      flag = false
      File.foreach(log_file_path) do |line|
        begin
          temp_line = line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
        rescue
          temp_line = line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
        end
        flag = true if MAVEN_ERROR_FLAG =~ temp_line
        flag = false if flag && temp_line =~ /[0-9]+ error|Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin/
        array << temp_line if flag && line_validate?(temp_line)
      end
      array
    end

    def self.use_build_tool(log_file_path)
      count_maven = 0
      count_gradle = 0
      File.foreach(log_file_path) do |line|
        count_maven += 1 if line.include?('mvn') || line.include?('Reactor Summary')
        count_gradle += 1 if line.include?('gradle')
      end
      hash = Hash.new
      hash[:maven] = true if count_maven >= 2
      hash[:gradle] = true if count_gradle >= 2
      hash
    end

    def self.compiler_error_message_slice(log_file_path)
      hash = use_build_tool(log_file_path)
      mslice = nil
      gslice = nil
      mslice = maven_slice(log_file_path) if hash[:maven]
      gslice = gradle_slice(log_file_path) if hash[:gradle]
      segment_array = []
      segment_array += segment_slice(mslice) if mslice && mslice.length > 0
      segment_array += segment_slice(gslice) if gslice && gslice.length > 0
      output = File.expand_path(File.join('..', 'assets', 'output', 'output'), File.dirname(__FILE__))
      index = 0
      while segment = segment_array.shift
        hash[:output] = output
        hash[:index] = index
        hash[:key], hash[:value] = map(segment)
        hash[:segment] = segment
        index += 1
        @queue.enq hash
      end
    end

    def self.queue_initialize
      @queue = SizedQueue.new(50)
    end

    def self.scan_log_directory(build_logs_path)
      output = File.expand_path(File.join('..', 'assets', 'output', 'output'), File.dirname(__FILE__))
      dirname = File.dirname(output)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
      queue_initialize


      consumer = Thread.new do
        File.open(output, 'a') do |f|
          loop do
            hash = @queue.deq
            break if hash == :END_OF_WORK
            f.puts
            f.puts '======================================'
            f.puts hash[:output]
            f.puts "#{hash[:key]}: #{hash[:value]}: #{@regex_hash[hash[:key]]}"
            f.puts
            hash[:segment].lines.each{ |line| f.puts line }
            f.puts
            hash = nil
          end
        end
      end
      threads = []
      Thread.list.each{ |thread| threads << thread }
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
            compiler_error_message_slice p
          end
          loop do
            break if Thread.list.count{ |thread| thread.alive? } <= 50
          end
        end
      end
      @queue.enq(:END_OF_WORK)
      Thread.list.each{ |thread| thread.join if thread.alive? && !threads.include?(thread)}
      consumer.join
    end
  end
end

Thread.abort_on_exception = true
#build_logs_path = ARGV[0]||'../../bodyLog2/build_logs/'

#scan_log_directory build_logs_path
