#! /usr/bin/ruby
require 'csv'
file_path = File.expand_path('java_repo.csv', File.dirname(__FILE__))

CSV.readlines(file_path, headers: true).reverse_each do |line|
    repo_name = line[1]
    source = 'fdse@10.141.221.85:~/user/zc/bodyLog2/build_logs/' + repo_name.sub(/\//, '@')
    dest = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
    p repo_name
    `rsync -avz #{source} #{dest}`
    p '#{repo_name} over'
end
