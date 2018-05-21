log_file_path = '/Users/zhangchen/projects/bodyLog2/build_logs/AnyChart@AnyChart-Android/55@1.log'
s = IO.read(log_file_path)
s = s.gsub!(/[^[:print:]\e\n]/, '') || s
s = s.gsub!(/\e[^m]+m/, '') || s
s = s.gsub!(/\e[^m]+m/, '') || s
 #.gsub!(/[^[:print:]\e\n]/, '').gsub!(/\e[^m]+m/, '').gsub!(/\e[^m]+m/, '')gsub!(/\e[^m]+m/, '')
 s.lines.each do |line|
  p line
 end
