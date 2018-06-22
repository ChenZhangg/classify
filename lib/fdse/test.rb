log_file_path = '/Users/zhangchen/projects/classify/lib/fdse/435@2.log'
MAVEN_ERROR_FLAG = /COMPILATION ERROR/i
GRADLE_ERROR_FLAG = /Compilation failed/i
def use_build_tool(file, hash) 
  count_maven = 0
  count_gradle = 0
  file.scan(/mvn|Reactor Summary|gradle|COMPILATION ERROR|Compilation failed/i) do |word|
    case word
    when 'mvn', 'Reactor Summary'
      count_maven += 1
    when 'gradle'
      count_gradle += 1
    when 'COMPILATION ERROR'
      hash[:maven_compiler_error] = 1
    when 'Compilation failed'
      hash[:gradle_compiler_error] = 1
    end       
    hash[:maven_error_not_precise] = 1 if MAVEN_ERROR_FLAG =~ word
    hash[:gradle_error_not_precise] = 1 if GRADLE_ERROR_FLAG =~ word
  end
  hash[:maven] = count_maven >= 2 ? 1 : 0
  hash[:gradle] = count_gradle >= 2 ? 1 : 0
end

file = IO.read log_file_path
hash = Hash.new
use_build_tool(file, hash)
puts hash