require "rake/testtask"
task :default => :test

Rake::TestTask.new('test') do |t|
  #t.libs << "test"
  t.pattern = "test/test_*.rb"
  t.verbose = true
end

task :log do
  ruby '-J-XX:+HeapDumpOnOutOfMemoryError -Ilib bin/classify.rb'
end