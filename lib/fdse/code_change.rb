require 'git'
# 需要链接哪些东西
# 出编译错误的地方的代码，diff中可能关联部分
# 确定相关的commit, 错误的，修复的
#
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

    def segment_analyze(segment, )
    attr_reader :g
  end
end
cc = Fdse::CodeChange.new 'checkstyle/checkstyle'
diff = cc.push_error_induce('525d63ca9be5cfec2eed2adfa3a167f2e0106ae8', 'f18e78b27f80420fae685d9ff5e36f8c0e079c97')
p diff.from
p diff.to
p diff.size
p diff.stats
p diff.lines
p diff.name_status
diff.patch.lines.each do |line|
  puts line
end

diff.each do |e|
  p e
end