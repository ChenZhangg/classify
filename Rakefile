require "rake/testtask"
task :default => :test

Rake::TestTask.new('test') do |t|
  #t.libs << "test"
  t.pattern = "test/test_*.rb"
  t.verbose = true
end

task :property do
  ruby '-Ilib bin/property.rb'
end

task :log do
  ruby '-J-Xmx6144m -Ilib bin/classify.rb'
end

task :slice do
  ruby '-J-XX:+UseParallelGC -J-XX:NewRatio=1 -J-Xms10g -J-Xmx10g -Ilib bin/slice_run.rb'
end