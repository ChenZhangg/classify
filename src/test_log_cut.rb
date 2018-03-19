require 'set'
@maven_error_message='COMPILATION ERROR'
@gradle_error_message='Compilation failed'

def gradleCutSegment(log_file_path)
  count=-1
  file_lines=IO.readlines(log_file_path).collect!{|line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")}
  file_lines.each_with_index do|line,index|
    next unless Regexp.new(@gradle_error_message)=~line
    count+=1
    k=index-11
    if line=~/[0-9]+%/
      while k>0 && file_lines[k]!~/(?<!\d)0%/
        k-=1
      end
    else
      if file_lines[index-1]!~/Execution failed for task/
        while k>0 && file_lines[k]!~/:compileTestJava|:compileJava|\.\/gradle/
          k-=1
        end
      else
        match=/.*'(.+)'/.match file_lines[index-1]

        while k>0 && file_lines[k]!~/:compileTestJava|:compileJava|\.\/gradle|travis_time/ && file_lines[k]!~/^#{match[1]}/
          k-=1
        end
      end
    end

    segment=''
    (k..index).each do |k|
      segment+=file_lines[k] if file_lines[k]!~/Download\s*http/i && file_lines[k]!~/downloaded.*KB\/.*KB/i && file_lines[k]!~/at [.$\w\d]+\([.$\w\d]+:[0-9]+\)/i
    end
    puts segment
=begin
    File.open('gradleCutSegment','a') do |output|
      output.puts
      output.puts "Segment #{count} in #{log_file_path} is:"
      output.puts segment
      output.puts '===============End================='
      output.puts
    end
=end
  end
end

def mavenOrGradle(log_file_path)

  puts "--Scanning file: #{log_file_path}"
  file=IO.read(log_file_path).gsub(/\r\n?/, "\n")

  if file.scan(/gradle/i).size >= 2
    print '>>>>>>>>>>>>>>>>>>>>>>>>>',' USE Gradle'
    puts
    gradleCutSegment(log_file_path)
  end

end

def traverseDir(build_logs_path)
  (Dir.entries(build_logs_path)).delete_if {|repo_name| /.+@.+/!~repo_name}.each do |repo_name|
    repo_path=File.join(build_logs_path,repo_name)
    puts "Scanning projects: #{repo_path}"
    Dir.entries(repo_path).delete_if {|log_file_name| /.+@.+/!~log_file_name}.sort_by!{|e| e.sub(/\.log/,'').sub(/@/,'.').to_f}.each do |log_file_name|
      log_file_path=File.join(repo_path,log_file_name)
      mavenOrGradle(log_file_path)
    end
  end
end

@build_logs_path='../../bodyLog2/build_logs/'
#traverseDir(@build_logs_path)
gradleCutSegment('923@1.log')