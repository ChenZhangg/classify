require 'fileutils'
require 'thread'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'activerecord-import'
require 'temp_job_datum'
require 'temp_compilation_slice'

module Fdse
  class ExtractCompilationInfo
    MAVEN_ERROR_FLAG = /COMPILATION ERROR/
    GRADLE_ERROR_FLAG = /> Compilation failed; see the compiler error output for details/
    GRADLE_ERROR_FLAG_1 = /Compilation failed|Compilation error/
    GRADLE_ERROR_UP_BOUNDARY = /:compileTestJava|:compileJava|:compileKotlin|:compileTestKotlin|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala|\.\/gradle|travis_time/
    SEGMENT_BOUNDARY = "/home/travis"
    SEGMENT_BOUNDARY_FILE = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.(java|groovy|scala|kt|sig)/
    SEGMENT_BOUNDARY_JAVA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.java/
    SEGMENT_BOUNDARY_GROOVY = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.groovy/
    SEGMENT_BOUNDARY_SCALA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.scala/
    SEGMENT_BOUNDARY_KOTLIN = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.kt/
    SEGMENT_BOUNDARY_SIG = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.sig/
    SEGMENT_BOUNDARY_JAR = /(\/[^\n\/]+){2,}\/\w+[-\w\d]*\.jar/
    SEGMENT_BOUNDARY_JAVAC_ERROR = /Failure executing javac, but could not parse the error/

    def self.gradle_slice(file_array_reverse)
      array = []
      flag = false
      count = 7
      regexp = /zhang chen/
      temp = []
      file_array_reverse.each do |line|
        if GRADLE_ERROR_FLAG_1 =~ line
          flag = true
          temp = []
          count = 7
        end
        if flag && count == 6
          match = /Execution failed for task '(.+)'/.match(line)
          regexp = /^#{match[1]}/ if match
        end
        temp.unshift(line) if flag
        if flag && count <=0 && (line =~ GRADLE_ERROR_UP_BOUNDARY || line =~ regexp || line =~ /(?<!\d)0%/)
          flag = false
          s = temp.join
          temp = nil
          mark = true
          array.each do |item|
            mark = false if item.eql?(s)
          end
          array << s if mark
        end
        count -= 1
      end
      array << temp.join if temp
      array
    end

    def self.maven_slice(file_array)
      array = []
      flag = false
      temp = nil
      file_array.each do |line|
        if MAVEN_ERROR_FLAG =~ line
          flag = true
          temp = [] 
        end
        if flag && line =~ /[0-9]+ error|Failed to execute goal|--------------------------------------/  
          flag = false 
          s = temp.join
          temp = nil
          mark = true
          array.each do |item|
            mark = false if item.eql?(s)
          end
          array << s if mark
        end
        temp << line if flag
      end
      array << temp.join if temp
      array
    end

    def self.compiler_error_message_slice(log_hash)
      file_array = IO.readlines(log_hash[:log_path])
      file_array.collect! do |line|
        begin
          line.sub(/\r\n?/, "\n")  
        rescue
          line.encode('ISO-8859-1', 'ISO-8859-1').sub(/\r\n?/, "\n")
        end
        line
      end
      
      mslice = []
      gslice = []

      mslice = maven_slice(file_array) if log_hash[:maven]
      gslice = gradle_slice(file_array.reverse!) if log_hash[:gradle]

      hash = Hash.new
      hash[:repo_name] = log_hash[:repo_name]
      hash[:job_number] = log_hash[:job_number]
      hash[:maven_slice] = mslice.length > 0 ? mslice : nil
      hash[:gradle_slice] = gslice.length > 0 ? gslice : nil

      @out_queue.enq hash
    end

    def self.thread_init
      @queue = SizedQueue.new(200)
      @repo_queue = SizedQueue.new(200)

      consumer = Thread.new do
        id = 0
        loop do
          hash = nil
          bulk = []
          200.times do
            hash = @out_queue.deq
            break if hash == :END_OF_WORK
            id += 1
            hash[:id] = id
            bulk << TempCompilationSlice.new(hash)
          end
          TempCompilationSlice.import bulk
          break if hash == :END_OF_WORK
       end
      end
      threads = []
      126.times do
        thread = Thread.new do
          loop do
            hash = @in_queue.deq
            break if hash == :END_OF_WORK
            compiler_error_message_slice hash
          end
        end
        threads << thread
      end
      [consumer, threads]
    end

    def self.scan_log_directory(logs_path)
      Thread.abort_on_exception = true
      consumer, threads = thread_init
      TempJobDatum.where("id > ? AND (maven_error_not_precise = 1 OR gradle_error_not_precise = 1)", 0).find_each do |job|
        repo_name = job.repo_name
        job_number = job.job_number
        log_path = File.join(logs_path, repo_name.sub(/\//, '@'), job_number.sub(/\./, '@') + '.log')
        puts "Scanning log: #{log_path}"
        hash = Hash.new
        hash[:log_path] = log_path
        hash[:repo_name] = repo_name
        hash[:job_number] = job_number
        hash[:maven] = job.maven
        hash[:gradle] = job.gradle
        hash[:maven_error_not_precise] = job.maven_error_not_precise
        hash[:gradle_error_not_precise] = job.gradle_error_not_precise
        @in_queue.enq hash
        end
      end
  
      126.times do
        @in_queue.enq :END_OF_WORK
      end
      threads.each { |t| t.join }
      @out_queue.enq :END_OF_WORK
      consumer.join
      puts "Scan Over"
    end
  end
end
