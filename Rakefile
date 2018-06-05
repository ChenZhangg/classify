require "rake/testtask"
task :default => :test

Rake::TestTask.new('test') do |t|
  #t.libs << "test"
  t.pattern = "test/test_property.rb"
  t.verbose = true
end

task :property do
  ruby '-Ilib bin/property.rb'
end

task :log do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/classify.rb'
end

task :slice do
  ruby '-J-Xms10g -J-Xmx10g -Ilib bin/slice_run.rb'
end

task :match do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/match.rb'
end