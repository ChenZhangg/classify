require 'fileutils'
require 'thread'
require 'build_tool'
require 'travis_java_repository'
require 'activerecord-import'

module Fdse
  class JudgeBuildTool
    def self.use_build_tool(file, hash) 
      hash[:maven] = file.scan(/(Reactor Summary|mvn)/m).size >= 2 ? 1 : 0
      hash[:gradle] = file.scan(/gradle/m).size >= 2 ? 1 : 0
      hash[:ant] = file.scan(/ant/m).size >= 2 ? 1 : 0
    end

    def self.compiler_error_message_slice(hash)
      file = IO.read(hash[:log_file_path])
      begin
        file = file.gsub(/\r\n?/, "\n")
      rescue
        file = file.encode('ISO-8859-1', 'ISO-8859-1').gsub(/\r\n?/, "\n")
      end
      use_build_tool(file, hash)
      hash.delete :log_file_path
      @out_queue.enq hash
    end

    def self.thread_init
      @in_queue = SizedQueue.new(30)
      @out_queue = SizedQueue.new(200)

      consumer = Thread.new do
        id = 6226400
        loop do
          hash = nil
          bulk = []
          200.times do
            hash = @out_queue.deq
            break if hash == :END_OF_WORK
            id += 1
            hash[:id] = id
            bulk << BuildTool.new(hash)
          end
          BuildTool.import bulk
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

    def self.scan_log_directory(build_logs_path)
      consumer, threads = thread_init
      TravisJavaRepository.where("id >= ? AND builds >= ? AND stars>= ?", 1358099, 50, 25).find_each do |repo|
        repo_id = repo.id
        repo_name = repo.repo_name
        repo_path = File.join(build_logs_path, repo_name.sub(/\//, '@'))
        puts "Scanning projects: #{repo_id} #{repo_name} #{repo_path}"
        regexp = /(\d+)\.(\d+)/
        Dir.foreach(repo_path) do |log_file_name|
          next if /.+@.+/ !~ log_file_name
          log_file_path = File.join(repo_path, log_file_name)
          hash = Hash.new
          hash[:log_file_path] = log_file_path
          hash[:repo_name] = repo_name
          hash[:job_number] = log_file_name.sub(/@/, '.').sub(/\.log/, '')
          match = regexp.match hash[:job_number]
          hash[:build_number_int] = match[1].to_i
          hash[:job_order_number] = match[2].to_i
          @in_queue.enq hash
        end
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

