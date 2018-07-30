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
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/extract_compilation_info_run.rb'
end

task :werror do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/werror.rb'
end

task :extract_maven_warning_info do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/extract_maven_warning_info.rb'
end

task :compilation_info_match do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/compilation_info_match_run.rb'
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

task :fail_reason_update do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/fail_reason_update.rb'
end

task :fail_reason_is_test do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/fail_reason_is_test.rb'
end

task :user_info do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/user_info_run.rb'
end

task :timezone do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/timezone.rb'
end

task :extract_compare_info do
  ruby '-J-Xms12g -J-Xmx12g -Ilib bin/extract_compare_info_run.rb'
end

task :zc_test do
  ruby '-J-Xms4g -J-Xmx4g -Ilib bin/zc_test.rb'
end

task :compilation_error_phase do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/compilation_error_phase.rb'
end

task :commit_error_task do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/compilation_error_task.rb'
end

task :commit_info_run do
  ruby '-J-Xms8g -J-Xmx8g -Ilib bin/commit_info_run.rb'
end