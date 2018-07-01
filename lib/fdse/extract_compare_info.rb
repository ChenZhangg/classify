require 'net/http'
require 'open-uri'
require 'nokogiri'
require 'temp_job_datum'
require 'thread'
module Fdse
  module ExtractCompareInfo
    def self.crawl(url)
      html = nil
      begin
        open(url) { |r| html = Nokogiri::HTML(r) }
      rescue
        puts $!
        puts $@
        return [nil, nil]
      end
      summary = Hash.new(0)
      html.css('#toc>div:eq(2)').each do |row| 
        changed_file = nil
        row.css('button').each { |row| changed_file = row.content }
        changed_file_regexp = /(\d)+ changed file/
        match = changed_file_regexp.match changed_file
        changed_file_number = match[1].to_i
        #addition_regexp = /(\d)+ additions/
        #deletion_regexp = /(\d)+ deletions/
        addition_deletion_regexp = /[,\d]+/
        addition_number = nil
        deletion_number = nil
        row.css('strong').each do |row| 
          content = row.content 
          m = addition_deletion_regexp.match content
          if content.include?('addition')
            addition_number = m[0].gsub(/,/, '').to_i
          elsif content.include?('deletion')
            deletion_number = m[0].gsub(/,/, '').to_i
          end
        end
        summary[:changed_file_number] = changed_file_number
        summary[:addition_number] = addition_number
        summary[:deletion_number] = deletion_number
      end
      file_list = []
      num_regexp = /[,\d]+/
      html.css('#toc>ol li').each do |row| 
        file_datum = Hash.new
        content = nil
        row.css('.text-green').each { |row| content = row.content }
        match = num_regexp.match content
        file_datum[:addition_number] = match ? match[0].gsub(/,/, '').to_i : 0
        row.css('.text-red').each { |row| content = row.content }
        match = num_regexp.match content
        file_datum[:deletion_number] = match ? match[0].gsub(/,/, '').to_i : 0
        row.css('a').each { |row| file_datum[:file_name] = row.content }
        file_list << file_datum
      end
      [summary, file_list]
    end

    def self.thread_init
      @in_queue = SizeQueue.new(30)

    end

    def self.scan_job
      TempJobDatum.where("id >= ? AND (job_state = ? OR job_state = ?)", 2999870, 'errored', 'failed').find_each do |job|
      end
      url_regexp = /\/compare\/.+/
      TimeCost.where('id > ?', 0).find_each do |cost|
        id = cost.id
        repo_name = cost.repo_name
        job_number = cost.now
        job = JavaRepoJobDatum.find_by(repo_name: repo_name, job_number: job_number)
        compare_url = job.commit_compare_url
        next if compare_url !~ url_regexp
        puts "#{id}-->#{compare_url}"
        summary, file_list = crawl(compare_url)
        puts summary
        puts file_list
        next if summary.nil?
        cost.update(changed_file_number: summary[:changed_file_number], addition_number: summary[:addition_number], 
          deletion_number: summary[:deletion_number], file_list: file_list)
      end
    end
  end
end