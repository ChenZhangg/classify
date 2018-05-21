require 'set'
require 'fdse/property'
require 'fileutils'
require 'thread'
require 'travis_java_repository'
require 'compiler_error_slice'
require 'java_repo_build_datum'
require 'elif'
require 'activerecord-import'

module Fdse
  class Slice
    MAVEN_ERROR_FLAG = /COMPILATION ERROR/
    GRADLE_ERROR_FLAG = /> Compilation failed; see the compiler error output for details/
    GRADLE_ERROR_FLAG_1 = /Compilation failed/i
    GRADLE_ERROR_UP_BOUNDARY = /:compileTestJava|:compileJava|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala|\.\/gradle|travis_time/
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
      #Elif.foreach(log_file_path) do |line|
      file_array_reverse.each do |line|
        if GRADLE_ERROR_FLAG =~ line
          flag = true
          count = 7
        end
        if flag && count == 6
          match = /Execution failed for task '(.+)'/.match(line)
          regexp = /^#{match[1]}/ if match
        end
        array.unshift(line) if flag
        if flag && count <=0 && (line =~ GRADLE_ERROR_UP_BOUNDARY || line =~ regexp || line =~ /(?<!\d)0%/)
          flag = false
        end
        count -= 1
      end
      array
    end

    def self.maven_slice(file_array)
      array = []
      flag = false
      file_array.each do |line|
        flag = true if MAVEN_ERROR_FLAG =~ line
        array << line if flag
        flag = false if flag && line =~ /[0-9]+ error|Failed to execute goal org.apache.maven.plugins:maven-compiler-plugin/  
      end
      array
    end

    def self.use_build_tool(file_array_reverse)    
      maven_flag = false
      gradle_flag = false
      file_array_reverse.each do |line|
        maven_flag = true if maven_flag == false && MAVEN_ERROR_FLAG =~ line
        gradle_flag = true if gradle_flag =false && GRADLE_ERROR_FLAG_1 =~ line

      end
      hash = Hash.new
      hash[:maven] = maven_flag
      hash[:gradle] = gradle_flag
      hash
    end

    def self.compiler_error_message_slice(log_file_path, repo_name, job_number)
      file_array = IO.readlines(log_file_path).collect! do |line|
        begin 
          line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
        rescue
          line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
        end
      end
      file_array_reverse = file_array.reverse
      h = use_build_tool(file_array_reverse)
      mslice = []
      gslice = []
      mslice = maven_slice(file_array) if h[:maven]
      gslice = gradle_slice(file_array_reverse) if h[:gradle]
      array = mslice + gslice

      hash = Hash.new
      hash[:repo_name] = repo_name
      hash[:job_number] =job_number
      hash[:has_compiler_error] = (h[:maven] || h[:gradle]) ? true : false
      hash[:slice_segment] = array.join
      @queue.enq hash
    end

    def self.scan_log_directory(build_logs_path)
      @queue = SizedQueue.new(200)
      consumer = Thread.new do
        id = 2824121
        loop do
          bulk = []
          200.times do
            hash = @queue.deq
            break if hash == :END_OF_WORK
            id += 1
            hash[:id] = id
            bulk << CompilerErrorSlice.new(hash)
          end
          CompilerErrorSlice.import bulk
       end
      end

      TravisJavaRepository.where("id > ? AND builds >= ? AND stars>= ?", 273885, 50, 25).find_each do |repo|
        repo_name = repo.repo_name
        repo_path = File.join(build_logs_path, repo_name.sub(/\//, '@'))
        puts "Scanning projects: #{repo_path}"
        Dir.foreach(repo_path) do |log_file_name|
          next if /.+@.+/ !~ log_file_name
          log_file_path = File.join(repo_path, log_file_name)
          puts "--Scanning file: #{log_file_path}"

          Thread.new(log_file_path, repo_name, log_file_name.sub(/@/, '.').sub(/\.log/, '')) do |p, r, n|
            compiler_error_message_slice p, r, n
          end

          loop do
            count = Thread.list.count{ |thread| thread.alive? }
            break if count <= 200
          end
        end
      end
      consumer.join
      sleep 1200
      @queue.enq(:END_OF_WORK)
      puts "Scan Over"
    end
  end
end

Thread.abort_on_exception = true
#build_logs_path = ARGV[0]||'../../bodyLog2/build_logs/'

#scan_log_directory build_logs_path