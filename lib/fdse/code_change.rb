require 'git'
module Fdse
  class CodeChange
    def initialize(path)
      @g = Git.open(path, :log => Logger.new(STDOUT))
    end

    def push_error_induce(sha_pre, sha_next)

    end
  end
end