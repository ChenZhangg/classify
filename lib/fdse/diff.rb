require_relative 'printer'
module Fdse
  module Diff
    Line = Struct.new(:number, :text)

    Edit = Struct.new(:type, :old_line, :new_line) do
      def old_number
        old_line ? old_line.number.to_s : ""
      end

      def new_number
        new_line ? new_line.number.to_s : ""
      end

      def text
        (old_line || new_line).text
      end
    end

    def self.lines(file)
      file.map.with_index { |text, index| Line.new(index + 1, text) }
    end

    def self.shortest_edit(lines_old, lines_new)
      m, n = lines_old.length, lines_new.length
      max = n + m
      v = Array.new(2 * max + 1)
      v[1] = 0
      trace = []
      (0 .. max).step do |d|
        trace << v.clone
        (-d .. d).step(2) do |k|
          if k == -d or (k != d and v[k - 1] < v[k + 1])
            x = v[k + 1]
          else
            x = v[k - 1] + 1
          end

          y = x - k
          while x < m and y < n and lines_old[x].text == lines_new[y].text
            x, y = x + 1, y + 1
          end

          v[k] = x
          return trace if x >= m and y >= n
        end
      end
    end

    def self.backtrack(lines_old, lines_new)
      x, y = lines_old.length, lines_new.length
      trace = shortest_edit(lines_old, lines_new)
      trace.each_with_index.reverse_each do |v, d|
        k = x - y
        if k == -d or (k != d and v[k - 1] < v[k + 1])
          prev_k = k + 1
        else
          prev_k = k - 1
        end
        prev_x = v[prev_k]
        prev_y = prev_x - prev_k
        while x > prev_x and y > prev_y
          yield x - 1, y - 1, x, y
          x, y = x - 1, y - 1
        end
        yield prev_x, prev_y, x, y if d > 0
        x, y = prev_x, prev_y
      end
    end

    def self.diff(old, new)
      fail('Not a valid file path!') if !File.exist?(old) && !File.exist?(new)
      old, new = lines(File.readlines(old)), lines(File.readlines(new))
      diff = []
      backtrack(old, new)do |prev_x, prev_y, x, y|
        old_line, new_line = old[prev_x], new[prev_y]
        if x == prev_x
          diff.unshift(Edit.new(:ins, nil, new_line))
        elsif y == prev_y
          diff.unshift(Edit.new(:del, old_line, nil))
        else
          diff.unshift(Edit.new(:eql, old_line, new_line))
        end
      end
      diff
    end
  end
end
Fdse::Printer.new.print(Fdse::Diff.diff('old', 'new'))
