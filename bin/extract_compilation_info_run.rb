#! /usr/bin/ruby
require 'fdse/extract_compilation_info'

build_logs_path = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
Fdse::ExtractCompilationInfo.scan_log_directory build_logs_path