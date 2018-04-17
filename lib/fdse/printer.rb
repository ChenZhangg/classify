module Fdse
  class Printer

    TAGS = {eql: " ", del: "-", ins: "+"}

    COLORS = {
        del:     "\e[31m",
        ins:     "\e[32m",
        default: "\e[39m"
    }

    LINE_WIDTH = 4

    def initialize(output: $stdout)
      @output = output
      @colors = output.isatty ? COLORS : {}
    end

    def print(diff)
      diff.each { |edit| print_edit(edit) }
    end

    def print_edit(edit)
      col   = @colors.fetch(edit.type, "")
      reset = @colors.fetch(:default, "")
      tag   = TAGS[edit.type]

      old_line = edit.old_number.rjust(LINE_WIDTH, " ")
      new_line = edit.new_number.rjust(LINE_WIDTH, " ")
      text     = edit.text.rstrip

      @output.puts "#{col}#{tag} #{old_line} #{new_line}    #{text}#{reset}"
    end
  end
end
