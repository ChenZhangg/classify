#! /usr/bin/ruby
require 'fdse/parse_log_file'

build_logs_path = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
Fdse::ParseLogFile.scan_log_directory build_logs_path