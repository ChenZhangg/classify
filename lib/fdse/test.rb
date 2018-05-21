MAVEN_ERROR_FLAG = /COMPILATION ERROR/
GRADLE_ERROR_FLAG = /> Compilation failed; see the compiler error output for details/
GRADLE_ERROR_FLAG_1 = /Compilation failed/i
#file_array = IO.readlines '../../../bodyLog2/build_logs/stormpath@stormpath-sdk-java/2152@4.log'
#file_array_reverse = file_array.reverse
file_array = IO.readlines('../../../bodyLog2/build_logs/stormpath@stormpath-sdk-java/2152@4.log').collect! do |line|
  begin 
    line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
  rescue
    line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n")
  end
end
file_array.each do |single|
  p single
end
