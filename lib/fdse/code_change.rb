require 'git'
module Fdse
  class CodeChange
    def initialize(path)
      @g = Git.clone(path, 'clone.git', :bare => true)
    end

    def push_error_induce(sha_pre, sha_next)

    end
  end
  attr_reader :g
end
cc = Fdse::CodeChange.new 'git@github.com:checkstyle/checkstyle.git'
p cc.g