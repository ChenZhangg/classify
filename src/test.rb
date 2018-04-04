file_lines = IO.readlines('913@10.log', :encoding => 'ISO-8859-1').collect!{ |line| line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '').gsub(/\r\n?/, "\n") }
file_lines.each {|line| p line}