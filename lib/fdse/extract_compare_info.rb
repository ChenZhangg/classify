require 'net/http'
require 'open-uri'
require 'nokogiri'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'activerecord-import'
require 'temp_job_datum'
require 'github_compare_datum'
require 'thread'
module Fdse
  module ExtractCompareInfo
    def self.crawl(hash)
      url = hash[:compare_url]
      html = nil
      begin
        open(url) { |r| html = Nokogiri::HTML(r) }
      rescue
        puts url
        puts $!
        puts $@
        @out_queue.enq hash
        return
      end
      commit_sha_regexp = /commit:(.+)/
      commit_array = []
      html.css('.commit').each do |commit|
        data_channel = commit.attribute('data-channel')
        match = commit_sha_regexp.match data_channel
        commit_array << match[1]
      end
      hash[:commits] = commit_array
      hash[:commits_number] = commit_array.length

      file_array = []
      addition_regexp = /[,\d]+/m
      deletion_regexp = /[,\d]+/m
      html.css('.content > li').each do |li|
        temp = []
        temp << li.css('a:not(.tooltipped)').first.content.dup
        temp << li.css('svg').first.attribute('title').to_s

        addition = li.css('.text-green').first ? li.css('.text-green').first.content.dup : '0'
        match = addition_regexp.match addition
        if match
          temp << match[0].gsub(/,/, '').to_i 
        else
          temp << 0
        end

        deletion = li.css('.text-red').first ? li.css('.text-red').first.content.dup : '0'
        match = deletion_regexp.match deletion
        if match
          temp << match[0].gsub(/,/, '').to_i 
        else
          temp << 0
        end
        file_array << temp
      end
      hash[:files] = file_array
      hash[:files_number] = file_array.length
      additions = 0
      deletions = 0
      file_array.each do |item|
        additions += item[2]
        deletions += item[3]
      end
      hash[:additions] = additions
      hash[:deletions] = deletions
      @out_queue.enq hash   
    end

    def self.thread_init
      @in_queue = SizedQueue.new(30)
      @out_queue = SizedQueue.new(200)

      consumer = Thread.new do
        #id = 91400
        loop do
          hash = nil
          bulk = []
          200.times do
            hash = @out_queue.deq
            break if hash == :END_OF_WORK
            #id += 1
            #hash[:id] = id
            bulk << GithubCompareDatum.new(hash)
          end
          GithubCompareDatum.import bulk
          break if hash == :END_OF_WORK
       end
      end
      threads = []
      30.times do
        thread = Thread.new do
          loop do
            hash = @in_queue.deq
            break if hash == :END_OF_WORK
            crawl hash
          end
        end
        threads << thread
      end
      [consumer, threads]
    end

    def self.run
      Thread.abort_on_exception = true
      consumer, threads = thread_init
      url_regexp = /\/compare\/.+/
      TempJobDatum.where("id > ? AND job_order_number = 1", 352124).find_each do |job|
        compare_url = job.commit_compare_url
        next if compare_url !~ url_regexp
        repo_name = job.repo_name
        build_number_int = job.build_number_int
        puts "Scan #{job.id}  #{repo_name}: #{build_number_int}"
        hash = Hash.new
        hash[:repo_name] = repo_name
        hash[:build_number_int] = build_number_int
        hash[:compare_url] = compare_url
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
  end
end