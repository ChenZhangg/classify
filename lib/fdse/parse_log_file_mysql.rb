require 'set'
require 'fdse/property'
require 'fileutils'
require 'thread'
require 'travis_java_repository'
require 'compiler_error_mysql_match'
require 'temp_match'
require 'java_repo_job_datum'
require 'activerecord-import'
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
    SEGMENT_BOUNDARY_JAR = /(\/[^\n\/]+){2,}\/\w+[-.\w\d]*\.jar/
    SEGMENT_BOUNDARY_JAVAC_ERROR = /Failure executing javac, but could not parse the error/
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
      segment_array = []
      return segment_array if segment_lines.length < 1
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

      slice_range.each do |range|
        segment_array << segment_lines[range].join if segment_lines[range.begin] !~ SEGMENT_BOUNDARY_GROOVY && segment_lines[range.begin] !~ SEGMENT_BOUNDARY_SCALA && segment_lines[range.begin] !~ SEGMENT_BOUNDARY_KOTLIN && segment_lines[range.begin] !~ SEGMENT_BOUNDARY_JAVAC_ERROR
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

    def self.compiler_error_message_slice(repo_name, job_number, java_repo_job_datum_id, slice_segment)
      temp_lines = slice_segment.lines
      lines = []
      temp_lines.each do |line|
        lines << line if  line_validate?(line)
      end
     
      segment_array = segment_slice(lines)

      order = 0

      while segment = segment_array.shift
        hash = Hash.new
        hash[:repo_name] = repo_name
        hash[:job_number] =job_number
        hash[:order_number] = order
        hash[:java_repo_job_datum_id] = java_repo_job_datum_id
        hash[:regex_key], hash[:similarity] = map(segment)
        hash[:segment] = segment
        order += 1
        @queue.enq hash
      end
    end

    def self.thread_init
      @queue = SizedQueue.new(200)
      @job_queue = SizedQueue.new(200)
      consumer = Thread.new do
        id = 0
        loop do
          bulk = []
          hash = nil
          200.times do
            hash = @queue.deq
            break if hash == :END_OF_WORK
            id += 1
            hash[:id] = id
            bulk << TempMatch.new(hash)
          end
          TempMatch.import bulk
          break if hash == :END_OF_WORK
       end
      end

      threads = []
      30.times do
        thread = Thread.new do
          loop do
            h = @job_queue.deq
            break if h == :END_OF_WORK
            compiler_error_message_slice h[:repo_name], h[:job_number], h[:java_repo_job_datum_id], h[:slice_segment]
          end
        end
        threads << thread
      end
      [consumer, threads]
    end

    def self.scan_log
      consumer, threads = thread_init
      JavaRepoJobDatum.where("id > 6485680 and has_compiler_error = 1").find_each do |job|
        puts "Scanning: #{job.id}: #{job.repo_name}  #{job.job_number}"
        hash = Hash.new
        hash[:repo_name] = job.repo_name
        hash[:job_number] = job.job_number
        hash[:java_repo_job_datum_id] = job.id
        hash[:slice_segment] = job.slice_segment
        @job_queue.enq hash
      end
      30.times do
        @job_queue.enq :END_OF_WORK
      end
      threads.each { |t| t.join }
      @queue.enq(:END_OF_WORK)
      consumer.join
      puts "Scan Over"
    end
  end
end

Thread.abort_on_exception = true
