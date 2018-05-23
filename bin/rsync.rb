#! /usr/bin/ruby
require 'csv'
CSV.readlines('java_repo.csv', headers: true).reverse_each do |line|
    repo_name = line[1]
    source = 'fdse@10.141.221.85:/home/fdse/user/zc/bodyLog2/build_logs/' + repo_name.sub(/\//, '@')
    dest = '/home/fdse/user/zc/bodyLog2/build_logs/'
    `rsync -avz #{source} #{dest}`
end