#! /usr/bin/ruby
require 'fdse/extract_test'

build_logs_path = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
Fdse::ExtractTest.run build_logs_path