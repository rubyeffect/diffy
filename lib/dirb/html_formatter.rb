module Dirb
  class HtmlFormatter
    def initialize(diff, options = {})
      @diff = diff
      @options = options
    end

    def to_s
      if @options[:highlight_words]
        wrap_lines(highlighted_words)
      else
        wrap_lines(@diff.map{|line| wrap_line(ERB::Util.h(line))})
      end
    end

    private
    def wrap_line(line)
      cleaned = line.gsub(/^./, '').chomp
      case line
      when /^\+/
        '    <li class="ins"><ins>' + cleaned + '</ins></li>'
      when /^-/
        '    <li class="del"><del>' + cleaned + '</del></li>'
      when /^ /
        '    <li class="unchanged"><span>' + cleaned + '</span></li>'
      end
    end

    def wrap_lines(lines)
      %'<div class="diff">\n  <ul>\n#{lines.join("\n")}\n  </ul>\n</div>\n'
    end

    def highlighted_words
      chunks = @diff.each_chunk.to_a
      processed = []
      lines = chunks.each_with_index.map do |chunk1, index|
        next if processed.include? index
        processed << index
        chunk1 = chunk1
        chunk2 = chunks[index + 1]
        if not chunk2
          next chunk1
        end

        chunk1 = ERB::Util.h(chunk1)
        chunk2 = ERB::Util.h(chunk2)

        dir1 = chunk1.each_char.first
        dir2 = chunk2.each_char.first
        case [dir1, dir2]
        when ['-', '+']
          line_diff = Dirb::Diff.new(
            split_characters(chunk1),
            split_characters(chunk2)
          )
          hi1 = reconstruct_characters(line_diff, '-')
          hi2 = reconstruct_characters(line_diff, '+')
          processed << (index + 1)
          [hi1, hi2]
        else
          chunk1
        end
      end.flatten
      lines.map{|line| line.each_line.map(&:chomp).to_a if line }.flatten.compact.
        map{|line|wrap_line(line) }.compact
    end

    def split_characters(chunk)
      chunk.gsub(/^./, '').each_line.map do |line|
        line.chomp.split('') + ['\n']
      end.flatten.join("\n")
    end

    def reconstruct_characters(line_diff, type)
      line_diff.each_chunk.map do |l|
        re = /(^|\\n)#{Regexp.escape(type)}/
        case l
        when re
          "<strong>" + l.gsub(re, '').gsub("\n", '').
            gsub('\n', "</strong>\n<strong>") + "</strong>"
        when /^ /
          l.gsub(/^./, '').gsub("\n", '').
            gsub('\r', "\r").gsub('\n', "\n")
        end
      end.join('').split("\n").map do |l|
        type + l
      end
    end
  end
end