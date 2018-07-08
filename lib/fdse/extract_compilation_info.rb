require 'fileutils'
require 'thread'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'activerecord-import'
require 'job'
require 'compilation_slice'

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
      temp = nil
      file_array_reverse.each do |line|
        if GRADLE_ERROR_FLAG_1 =~ line && /Caused by/ !~ line
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
        temp << line if flag
        if flag && line =~ /[0-9]+ error|Failed to execute goal/
          flag = false 
          s = temp.join
          temp = nil
          mark = true
          array.each do |item|
            mark = false if item.eql?(s)
          end
          array << s if mark
        end
      end
      array << temp.join if temp
      array
    end

    def self.compiler_error_message_slice(log_hash)
      file_array = IO.readlines(log_hash[:log_path])
      file_array.collect! do |line|
        begin
          sub = line.gsub(/\r\n?/, "\n")  
        rescue
          sub = line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/\r\n?/, "\n")
        end
        sub
      end
      
      mslice = []
      gslice = []

      mslice = maven_slice(file_array) if log_hash[:maven]
      gslice = gradle_slice(file_array.reverse!) if log_hash[:gradle]

      hash = Hash.new
      hash[:repo_name] = log_hash[:repo_name]
      hash[:job_number] = log_hash[:job_number]
      hash[:job_id] = log_hash[:job_id]
      hash[:maven_slice] = mslice.length > 0 ? mslice : nil
      hash[:gradle_slice] = gslice.length > 0 ? gslice : nil

      @out_queue.enq hash
    end

    def self.thread_init
      @in_queue = SizedQueue.new(30)
      @out_queue = SizedQueue.new(100)

      consumer = Thread.new do
        id = 101200
        loop do
          hash = nil
          bulk = []
          100.times do
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
      30.times do
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
      TempJobDatum.where("id > ? AND (maven_error_not_precise = 1 OR gradle_error_not_precise = 1)", 3237014).find_each do |job|
        repo_name = job.repo_name
        job_number = job.job_number
        log_path = File.join(logs_path, repo_name.sub(/\//, '@'), job_number.sub(/\./, '@') + '.log')
        puts "Scanning log:#{job.id} #{log_path}"
        hash = Hash.new
        hash[:log_path] = log_path
        hash[:repo_name] = repo_name
        hash[:job_number] = job_number
        hash[:job_id] = job.id
        hash[:maven] = job.maven
        hash[:gradle] = job.gradle
        hash[:maven_error_not_precise] = job.maven_error_not_precise
        hash[:gradle_error_not_precise] = job.gradle_error_not_precise
        @in_queue.enq hash
      end
  
      30.times do
        @in_queue.enq :END_OF_WORK
      end
      threads.each { |t| t.join }
      @out_queue.enq :END_OF_WORK
      consumer.join
      puts "Scan Over"
    end

    def self.werror
      CompilationSlice.where("id > ?", 0).find_each do |slice|
        maven_slice = slice.maven_slice
        gradle_slice = slice.gradle_slice
        werror = 0
        if maven_slice
          maven_slice.each do |segment|
            werror = 1 if segment.include?("Werror")
          end
        end

        if gradle_slice
          gradle_slice.each do |segment|
            werror = 1 if segment.include?("Werror")
          end
        end
        slice.werror = werror
        slice.save
      end
    end

  end
end
