require_relative 'property'
require 'set'
@maven_error_message='COMPILATION ERROR'
@gradle_error_message='Compilation failed'
@segment_cut="/home/travis"
file_lines=IO.readlines('898@2.log')
file_lines.each do |line|
  p line.gsub(/[^[:print:]\e\n]/, '').gsub(/\e[^m]+m/, '')
end
#map('file',f)