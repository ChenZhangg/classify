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
diff = cc.push_error_induce('63005f9a5e64f94ed3325188504f74e50e0fed88', '53d8e10fd3d049457f7aa3da503d48faef6264aa')
p diff.from
p diff.to
p diff.size
p diff.stats
p diff.lines