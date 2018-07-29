require 'open-uri'
require 'nokogiri'
require 'active_record'
require 'activerecord-jdbcmysql-adapter'
require 'activerecord-import'
require 'job'
require 'time_cost'
require 'thread'
module Fdse
  module CommitInfo

    def self.crawl(url)
      parent_commit_sha = nil
      html = nil
      begin
        open(url) { |r| html = Nokogiri::HTML(r) }
      rescue
        #puts url
        puts $!
        #puts $@
        return -1
      end

      regexp = /commit\/(.+)/
      html.css('a.sha').each do |a|
        href = a.attribute('href')
        m = regexp.match(href)
        parent_commit_sha = m[1]
        break
      end 
      return parent_commit_sha
    end

    def self.run
      TimeCost.where("id > ? AND pre = ?", 43896, "-1").find_each do |time_cost|
        repo_name = time_cost.repo_name
        job_number = time_cost.now
        puts "#{repo_name}: #{job_number}"
        job = Job.find_by("repo_name = ? AND job_number = ?", repo_name, job_number)
        job_order_number = job.job_order_number
        build_event_type = job.build_event_type
        commit_sha = job.commit_sha
        10.times do
          commit_url = 'https://github.com/' + repo_name + '/commit/' + commit_sha
          p commit_url
          parent_commit_sha = crawl(commit_url)
          break if parent_commit_sha == -1
          parent_job = Job.find_by("repo_name = ? AND commit_sha = ? AND job_order_number = ?", repo_name, parent_commit_sha, job_order_number)
          if parent_job
            p parent_job.job_number
            job.parent = parent_job.job_number
            job.save
            break
          end
          commit_sha = parent_commit_sha
        end
      end

      puts "Scan Over"
    end
  end
end