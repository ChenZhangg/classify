require 'git'
module Fdse
  class CodeChange
    def initialize(repo_name)
      file_path = File.expand_path(File.join('..', 'assets', 'git_repo', repo_name.sub(/\//, '@')), File.dirname(__FILE__))
      if File.exist? file_path
        @g = Git.open(file_path)
      else
        @g = Git.clone("https://github.com/#{repo_name}.git", file_path)
      end
    end

    def push_error_induce(sha_pre, sha_next)
      diff = @g.diff(sha_pre, sha_next)
    end
    attr_reader :g
  end
end
cc = Fdse::CodeChange.new 'checkstyle/checkstyle'
p cc.g