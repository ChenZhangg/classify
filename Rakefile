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
  ruby '-Ilib bin/classify.rb'
end