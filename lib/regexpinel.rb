require_relative "compiler"
require_relative "regexpinel/wrapper"

unless Object.private_method_defined?(:nr_on_match)
  def nr_on_match(start_pos, end_pos, capture_count)
    0
  end
end

module Regexpinel
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

    def instruction_count
      @code.length / 3
    end
  end

  CRuby = Pattern
end
