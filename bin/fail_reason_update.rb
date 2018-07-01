#! /usr/bin/ruby
require 'fdse/fail_reason'

build_logs_path = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
Fdse::FailReason.update build_logs_path