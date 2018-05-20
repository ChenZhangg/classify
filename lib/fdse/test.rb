require 'open3'
MAVEN_ERROR_FLAG = /COMPILATION ERROR/
GRADLE_ERROR_FLAG = /> Compilation failed; see the compiler error output for details/
GRADLE_ERROR_FLAG_1 = /Compilation failed/i
 
def use_build_tool(log_file_path)  
    File.foreach(log_file_path) do |line|
      maven_flag = true if MAVEN_ERROR_FLAG =~ line
      gradle_flag = true if GRADLE_ERROR_FLAG_1 =~ line
    end  
end
use_build_tool('../../../bodyLog2/build_logs/stormpath@stormpath-sdk-java/2152@4.log')