require 'rubygems'
require 'tempfile'
require 'open3'
require 'erb'
module Dirb
  class Diff
    class << self
      attr_writer :default_format
      def default_format
        @default_format || :text
      end
    end
    include Enumerable
    attr_reader :string1, :string2, :diff_options, :diff
    def initialize(string1, string2, diff_options = "-U 10000")
      @string1, @string2 = string1, string2
      @diff_options = diff_options
    end

    def diff
      @diff ||= Open3.popen3(
        *[diff_bin, diff_options, tempfile(string1), tempfile(string2)]
      ) { |i, o, e| o.read }
      @diff = @string1.gsub(/^/, " ") if @diff =~ /\A\s*\Z/
      @diff
    end

    def each &block
      diff.split("\n").reject{|x| x =~ /^---|\+\+\+|@@/ }.each do |line| 
        block.call line + "\n"
      end
    end

    def tempfile(string)
      t = Tempfile.new('dirb')
      t.print(string)
      t.flush
      t.path
    end

    def to_s(format = nil)
      format ||= self.class.default_format
      formats = Format.instance_methods(false).map{|x| x.to_s}
      if formats.include? format.to_s
        enum = self.to_a
        enum.extend Format
        enum.send format
      else
        raise ArgumentError,
          "Format #{format.inspect} not found in #{formats.inspect}"
      end
    end
    private

    def diff_bin
      bin = `which diff`.chomp
      if bin.empty?
        raise "Can't find a diff executable in PATH #{ENV['PATH']}"
      end
      bin
    end

    module Format
      def color
        map do |line|
          case line
          when /^\+/
            "\033[32m#{line.chomp}\033[0m"
          when /^-/
            "\033[31m#{line.chomp}\033[0m"
          else
            line.chomp
          end
        end.join("\n") + "\n"
      end

      def text
        to_a.join
      end

      def html
        lines = map do |line|
          case line
          when /^\+/
            '    <li class="ins"><ins>' + ERB::Util.h(line.gsub(/^./, '').chomp) + '</ins></li>'
          when /^-/
            '    <li class="del"><del>' + ERB::Util.h(line.gsub(/^./, '').chomp) + '</del></li>'
          when /^ /
            '    <li class="unchanged"><span>' + ERB::Util.h(line.gsub(/^./, '').chomp) + '</span></li>'
          end
        end
        %'<div class="diff">\n  <ul>\n#{lines.join("\n")}\n  </ul>\n</div>\n'
      end
    end
  end
end
