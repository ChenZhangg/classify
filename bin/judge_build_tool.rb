#! /usr/bin/ruby
require 'fdse/ant_maven_gradle'

build_logs_path = File.expand_path(File.join('..', '..', 'bodyLog2', 'build_logs'), File.dirname(__FILE__))
Fdse::AntMavenGradle.run build_logs_path