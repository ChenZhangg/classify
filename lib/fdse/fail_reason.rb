require 'fileutils'
require 'thread'
require 'job'
require 'wrong_slice'
require 'compilation_slice'
require 'activerecord-import'

module Fdse
  class FailReason
    def self.maven_slice(file_array)
      wrong_mark = []
      wrong_lines = []
      wrong_section_started = false

      file_array.each do |line|
        if ! line.valid_encoding?
          line = line.encode("UTF-16be", :invalid=>:replace, :replace=>"?").encode('UTF-8')
          puts line
        end

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
      [wrong_lines.join, wrong_mark.join]
    end

    def self.gradle_slice(file_array)
      wrong_lines = []
      wrong_section_started = false

      file_array.each do |line|
        if ! line.valid_encoding?
          line = line.encode("UTF-16be", :invalid=>:replace, :replace=>"?").encode('UTF-8')
          puts line
        end

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
      wrong_lines.join
    end


    def self.wrong_message_slice(hash)
      file_array = IO.readlines(hash[:log_file_path])
      file_array.collect! do |line|
        begin
          sub = line.sub(/\r\n?/, "\n")  
        rescue
          sub = line.encode('ISO-8859-1', 'ISO-8859-1').sub(/\r\n?/, "\n")
        end
        sub
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
        id = 1001379
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
      Job.where("id >= ? AND (job_state = ? OR job_state = ?)", 5145900, 'errored', 'failed').find_each do |job|
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

    def self.update(build_logs_path)
      WrongSlice.where("id > ?", 271271).find_each do |wrong|
        repo_name = wrong.repo_name
        job_number = wrong.job_number
        log_file_path = File.join(build_logs_path, repo_name.sub(/\//, '@'), job_number.sub(/\./, '@') + '.log')
        puts "wrong_slice: #{wrong.id} #{log_file_path}"
        file_array = IO.readlines log_file_path
        file_array.collect! do |line|
          begin
            sub = line.sub(/\r\n?/, "\n")  
          rescue
            sub = line.encode('ISO-8859-1', 'ISO-8859-1').sub(/\r\n?/, "\n")
          end
          sub
        end
        job = Job.find_by(repo_name: repo_name, job_number: job_number)

        if job.maven == 1
          maven_slice, maven_mark = maven_slice(file_array)
          wrong.maven_slice = maven_slice.length > 0 ? maven_slice : nil
          wrong.maven_mark = maven_mark.length > 0 ? maven_mark : nil
        end

        if job.gradle == 1
          gradle_slice = gradle_slice(file_array)
          wrong.gradle_slice = gradle_slice.length > 0 ? gradle_slice : nil
        end
        wrong.save
      end
    end

    def self.has_failed_test
      maven_mark = 'test failure'
      gradle_mark = 'failing test'
      WrongSlice.where("id > ?", 475998).find_each do |wrong|
        puts wrong.id
        maven = wrong.maven_mark
        gradle = wrong.gradle_slice
        flag = 0
        if maven && maven.include?(maven_mark)
          flag = 1
        end
        if gradle && gradle.include?(gradle_mark)
          flag = 1
        end
        wrong.test_failed = flag
        wrong.save
      end
    end

    def self.compilation_error_phase
      maven_production = /maven-compiler-plugin:[.\d]+:compile/
      maven_test = /maven-compiler-plugin:[.\d]+:testCompile/
      gradle_production = /:compileJava/
      gradle_test = /:compileTestJava/
      CompilationSlice.where("id > ?", 663).find_each do |slice|
        puts slice.id
        repo_name = slice.repo_name
        job_number = slice.job_number
        wrong_slice = WrongSlice.find_by(repo_name: repo_name, job_number: job_number)

        production = 0
        test = 0

        maven_mark = wrong_slice.nil? ? nil : wrong_slice.maven_mark
        gradle_slice = wrong_slice.nil? ? nil : wrong_slice.gradle_slice
        if maven_mark
          production = 1 if maven_mark =~ maven_production
          test = 1 if maven_mark =~ maven_test
        end

        if gradle_slice
          production = 1 if gradle_slice =~ gradle_production
          test = 1 if gradle_slice =~ gradle_test
        end
        slice.production = production
        slice.test = test
        slice.save
      end
    end

  end
end
