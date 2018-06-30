require 'fileutils'
require 'thread'
require 'temp_job_datum'
require 'wrong_slice'
require 'activerecord-import'

module Fdse
  class FailReason
    def self.maven_slice(file_array)
      wrong_mark = []
      wrong_lines = []
      wrong_section_started = false

      file_array.each do |line|
        if line =~ /BUILD FAILURE/
          wrong_section_started = true
          #temp_wrong_lines = []
        end

        if line =~ /To see the full stack trace of the error/ && wrong_section_started == true
          wrong_section_started = false
          #wrong_lines << temp_wrong_lines.join
        end
        wrong_lines << line if wrong_section_started
        wrong_mark << line if line =~ /Failed to execute goal/
      end
      [wrong_lines, wrong_mark]
    end

    def self.gradle_slice(file_array)
      wrong_lines = []
      wrong_section_started = false

      file_array.each do |line|
        if line =~ /What went wrong:/
          wrong_section_started = true
          #temp_wrong_lines = []
        end

       if line =~ /Try:/ && wrong_section_started == true
          wrong_section_started = false
          #wrong_lines << temp_wrong_lines.join
        end

        wrong_lines << line if wrong_section_started
      end
      wrong_lines
    end


    def self.wrong_message_slice(hash)
      file_array = IO.readlines(hash[:log_file_path])
      file_array.collect! do |line|
        begin
          line.sub(/\r\n?/, "\n")  
        rescue
          line.encode('ISO-8859-1', 'ISO-8859-1').sub(/\r\n?/, "\n")
        end
        line
      end

      if hash[:use_maven]
        maven_slice, maven_mark = maven_slice(file_array)
        hash[:maven_slice] = maven_slice.length > 0 ? maven_slice : nil
        hash[:maven_mark] = maven_mark.length > 0 ? maven_mark : nil
      end

      if hash[:use_gradle]
        gradle_slice = gradle_slice(file_array)
        hash[:gradle_slice] = gradle_slice.length > 0 ? gradle_slice : nil
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
        id = 438579
        loop do
          hash = nil
          bulk = []
          200.times do
            hash = @out_queue.deq
            break if hash == :END_OF_WORK
            id += 1
            hash[:id] = id
            bulk << WrongSlice.new(hash)
          end
          WrongSlice.import bulk
          break if hash == :END_OF_WORK
       end
      end

      threads = []
      30.times do
        thread = Thread.new do
          loop do
            hash = @in_queue.deq
            break if hash == :END_OF_WORK
            wrong_message_slice hash
          end
        end
        threads << thread
      end
      [consumer, threads]
    end

    def self.scan_log_directory(build_logs_path)
      consumer, threads = thread_init
      TempJobDatum.where("id >= ? AND (job_state = ? OR job_state = ?)", 2441300, 'errored', 'failed').find_each do |job|
        repo_name = job.repo_name
        job_number = job.job_number
        build_number_int = job.build_number_int
        job_order_number = job.job_order_number
        use_ant = job.ant == 1 ? true : false
        use_maven = job.maven == 1 ? true : false
        use_gradle = job.gradle == 1 ? true : false
        next if use_ant == false && use_maven == false && use_gradle == false
        log_file_path = File.join(build_logs_path, repo_name.sub(/\//, '@'), job_number.sub(/\./, '@') + '.log')
        next if File.exist?(log_file_path) == false
        puts "Scan #{job.id} #{log_file_path}"
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
