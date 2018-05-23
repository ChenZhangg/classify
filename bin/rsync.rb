#! /usr/bin/ruby
require 'csv'
require 'open3'
file_path = File.expand_path('java_repo.csv', File.dirname(__FILE__))

CSV.readlines(file_path, headers: true).reverse_each do |line|
    repo_name = line[1]
    source = 'fdse@10.141.221.85:~/user/zc/bodyLog2/build_logs/' + repo_name.sub(/\//, '@')
    dest = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
    Open3.popen3("rsync -avz #{source} #{dest}") do |i, o, e|
        while line = o.gets
            puts line
        end
    end
end
