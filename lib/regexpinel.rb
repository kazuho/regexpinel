require_relative "compiler"
require_relative "regexpinel/wrapper"

unless Object.private_method_defined?(:nr_on_match)
  def nr_on_match(start_pos, end_pos, capture_count)
    Regexpinel.record_match(start_pos, end_pos, capture_count)
    0
  end
end

module Regexpinel
  @last_match_start = -1
  @last_match_end = -1
  @last_match_capture_count = -1

  class << self
    attr_reader :last_match_start, :last_match_end, :last_match_capture_count
  end

  def self.record_match(start_pos, end_pos, capture_count)
    @last_match_start = start_pos
    @last_match_end = end_pos
    @last_match_capture_count = capture_count
    0
  end

  class Pattern
    attr_reader :pattern

    def self.compile(pattern)
      new(pattern)
    end

    def initialize(pattern)
      @pattern = pattern
      @code = Regexpinel.compile(pattern)
      @context = nr_make_context(@code.length / 3)
    end

    def match?(string, start_pos = 0)
      nr_run_with_context(@code, string, start_pos, @context)
    end

    def sub(string, replacement)
      range = find_match_range(string, 0)
      return string.dup unless range

      replace_range(string, range[0], range[1], replacement)
    end

    def gsub(string, replacement)
      result = string.byteslice(0, 0).dup
      search_pos = 0
      copy_pos = 0

      while search_pos <= string.bytesize
        range = find_match_range(string, search_pos)
        break unless range

        start_pos = range[0]
        end_pos = range[1]
        result << string.byteslice(copy_pos, start_pos - copy_pos).to_s
        result << replacement

        if end_pos == start_pos
          break if end_pos >= string.bytesize
          search_pos = utf8_next_pos(string, end_pos)
          result << string.byteslice(end_pos, search_pos - end_pos).to_s
          copy_pos = search_pos
        else
          search_pos = end_pos
          copy_pos = end_pos
        end
      end

      result << string.byteslice(copy_pos, string.bytesize - copy_pos).to_s
      result
    end

    def instruction_count
      @code.length / 3
    end

    private

    def find_match_range(string, start_pos)
      pos = start_pos
      while pos <= string.bytesize
        if nr_run_with_context(@code, string, pos, @context)
          return [Regexpinel.last_match_start, Regexpinel.last_match_end]
        end
        break if pos >= string.bytesize
        pos = utf8_next_pos(string, pos)
      end
      nil
    end

    def utf8_next_pos(string, pos)
      b0 = string.getbyte(pos)
      return pos + 1 if b0 < 128
      return pos + 2 if b0 < 224
      return pos + 3 if b0 < 240
      pos + 4
    end

    def replace_range(string, start_pos, end_pos, replacement)
      result = string.byteslice(0, 0).dup
      result << string.byteslice(0, start_pos).to_s
      result << replacement
      result << string.byteslice(end_pos, string.bytesize - end_pos).to_s
      result
    end
  end

  CRuby = Pattern
end
