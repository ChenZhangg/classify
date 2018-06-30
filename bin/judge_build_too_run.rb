#! /usr/bin/ruby
require 'fdse/judge_build_tool'

build_logs_path = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
Fdse::JudgeBuildTool.run build_logs_path