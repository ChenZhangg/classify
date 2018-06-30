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

task :extract_compilation_info do
  ruby '-J-Xms10g -J-Xmx10g -Ilib bin/extract_compilation_info_run.rb'
end

task :match do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/match.rb'
end

task :has_compilation_error do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/has_compilation_error_run.rb'
end

task :judge_build_tool do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/judge_build_tool_run.rb'
end

task :extract_test do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/extract_test_run.rb'
end

task :fail_reason do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/fail_reason_run.rb'
end

task :fail_reason do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/fail_reason_run.rb'
end

task :user_info do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/user_info_run.rb'
end

task :timezone do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/timezone.rb'
end