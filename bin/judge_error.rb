#! /usr/bin/ruby
require 'fdse/has_compilation_error'

build_logs_path = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
Fdse::Slice.scan_log_directory build_logs_path