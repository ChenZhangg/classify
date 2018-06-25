require 'fileutils'
require 'thread'
require 'temp_job_datum'
require 'build_tool'
require 'test_slice'
require 'activerecord-import'

module Fdse
  class ExtractTest
    def self.ant_slice(file_array)
      test_lines = []
      test_section_started = false
      line_marker = 0

      file_array.each do |line|
        if line =~ /\[(junit|testng|test.*)\] /
          test_section_started = true
        end

        if test_section_started
          test_lines << line
        end
      end
      test_lines
    end

    def self.maven_slice(file_array)
      test_lines = []
      test_section_started = false
      line_marker = 0

      file_array.each do |line|
        if (line =~ /-------------------------------------------------------/) && line_marker == 0
          line_marker = 1
        elsif (line =~ / T E S T S/) && line_marker == 1
          line_marker = 2
          test_section_started = true
          test_lines << "-------------------------------------------------------\n"
        elsif line =~ /\[INFO\] Reactor Summary:/ || line =~ /Building ([^ ]*)/
          test_section_started = false
        else
          line_marker = 0
        end
        test_lines << line if test_section_started
      end
      test_lines
    end

    def self.gradle_slice(file_array)
      test_lines = []
      test_section_started = false
      line_marker = 0

      file_array.each do |line|
        if line =~ /\A:(test|integrationTest)/
          line_marker = 1
          test_section_started = true
        elsif line =~ /\A:(\w*)/ && line_marker == 1
          line_marker = 0
          test_section_started = false
        end

        test_lines << line if test_section_started
      end
      test_lines
    end


    def self.test_message_slice(hash)
      file_array = IO.readlines(hash[:log_file_path])
      file_array.collect! do |line|
        begin
          line.gsub!(/\r\n?/, "\n")  
        rescue
          line.encode('ISO-8859-1', 'ISO-8859-1').gsub!(/\r\n?/, "\n")
        end
      end

      if hash[:use_ant]
        ant_slice = ant_slice(file_array)    
        hash[:ant_slice] = ant_slice.length > 0 ? ant_slice.join : nil
      end

      if hash[:use_maven]
        maven_slice = maven_slice(file_array)
        hash[:maven_slice] = maven_slice.length > 0 ? maven_slice.join : nil
      end

      if hash[:use_gradle]
        gradle_slice = gradle_slice(file_array)
        hash[:gradle_slice] = gradle_slice.length > 0 ? gradle_slice.join : nil
      end

      hash.delete :use_ant
      hash.delete :use_maven
      hash.delete :use_gradle
      hash.delete :log_file_path
      @out_queue.enq hash
    end

    def self.thread_init
      @in_queue = SizedQueue.new(30)
      @out_queue = SizedQueue.new(200)

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
            bulk << TestSlice.new(hash)
          end
          TestSlice.import bulk
          break if hash == :END_OF_WORK
       end
      end

      threads = []
      30.times do
        thread = Thread.new do
          loop do
            hash = @in_queue.deq
            break if hash == :END_OF_WORK
            test_message_slice hash
          end
        end
        threads << thread
      end
      [consumer, threads]
    end

    def self.scan_log_directory(build_logs_path)
      consumer, threads = thread_init
      TempJobDatum.where("id >= ? AND (job_state = ? OR job_state = ?)", 1, 'errored', 'failed').find_each do |job|
        repo_name = job.repo_name
        job_number = job.job_number
        build_number_int = job.build_number_int
        job_order_number = job.job_order_number
        build_tool = BuildTool.find_by(repo_name: repo_name, job_number: job_number)
        use_ant = build_tool.ant == 1 ? true : false
        use_maven = build_tool.maven == 1 ? true : false
        use_gradle = build_tool.gradle == 1 ? true : false
        next if use_ant == false && use_maven == false && use_gradle == false
        log_file_path = File.join(build_logs_path, repo_name.sub(/\//, '@'), job_number.sub(/\./, '@') + '.log')
        next if File.exist?(log_file_path) == false
        puts "Scan #{log_file_path}"
        hash = Hash.new
        hash[:repo_name] = repo_name
        hash[:job_number] = job_number
        hash[:build_number_int] = build_number_int
        hash[:job_order_number] = job_order_number
        hash[:use_ant] = use_ant
        hash[:use_maven] = use_maven
        hash[:use_gradle] = use_gradle
        hash[:log_file_path] = log_file_path
        @in_queue.enq hash
      end
   
      30.times do
        @in_queue.enq :END_OF_WORK
      end
      threads.each { |t| t.join }
      @out_queue.enq(:END_OF_WORK)
      consumer.join
      puts "Scan Over"
    end

    def self.run(build_logs_path)
      Thread.abort_on_exception = true
      scan_log_directory build_logs_path
    end
  end
end

