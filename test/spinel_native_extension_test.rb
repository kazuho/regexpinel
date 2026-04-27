#!/usr/bin/env ruby

require "rbconfig"
require_relative "../lib/compiler"
require_relative "../lib/runtime"

def build_spinel_extension
  root = File.expand_path("..", __dir__)
  bundle = File.join(root, "regexpinel_spinel.bundle")
  return if File.exist?(bundle)

  ruby = RbConfig.ruby
  unless system(ruby, "extconf.rb", chdir: root, out: File::NULL, err: File::NULL)
    raise "failed to configure Spinel extension"
  end
  unless system("make", chdir: root, out: File::NULL, err: File::NULL)
    raise "failed to build Spinel extension"
  end
end

build_spinel_extension
require_relative "../lib/regexpinel/spinel"

def nr_on_match(start_pos, end_pos, capture_count)
  0
end

module SpinelExtensionTest
  CASES = [
    ["ab", "ab", 0],
    ["ab", "ac", 0],
    ["ab", "zab", 1],
    ["a|b", "a", 0],
    ["a|b", "b", 0],
    ["a|b", "c", 0],
    ["a*", "", 0],
    ["a*", "aaa", 0],
    ["a+b", "aaab", 0],
    ["a+b", "b", 0],
    ["ab?", "a", 0],
    ["ab?", "ab", 0],
    [".b", "ab", 0],
    [".b", "zz", 0],
    ["a(b|c)d", "acd", 0]
  ].freeze

  module_function

  def assert_eq(actual, expected, label)
    return if actual == expected
    raise "FAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
  end

  def ruby_match?(code, input, start_pos)
    insn_count = code.length / 3
    current_states = Array.new(insn_count, 0)
    next_states = Array.new(insn_count, 0)
    mark_tokens = Array.new(insn_count, 0)
    epsilon_stack = Array.new(insn_count, 0)
    mark_token_box = [0]
    nr_match(code, input, start_pos, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
  end

  def main
    unless Regexpinel::Spinel.available?
      raise "spinel extension is not available"
    end

    CASES.each do |pattern, input, start_pos|
      code = Regexpinel.compile(pattern)
      expected = ruby_match?(code, input, start_pos)
      actual = Regexpinel::Spinel.match_code?(code, input, start_pos)
      assert_eq(actual, expected, "spinel #{pattern.inspect} on #{input.inspect} at #{start_pos}")

      spinel_pattern = Regexpinel::Spinel::Pattern.compile(pattern)
      pattern_actual = spinel_pattern.match?(input, start_pos)
      assert_eq(pattern_actual, expected, "spinel pattern #{pattern.inspect} on #{input.inspect} at #{start_pos}")

      spinel_regexp = Regexpinel::Spinel.new(pattern)
      regexp_actual = spinel_regexp.match?(input, start_pos)
      assert_eq(regexp_actual, expected, "spinel new #{pattern.inspect} on #{input.inspect} at #{start_pos}")
    end

    begin
      Regexpinel::Spinel.match_code?([NR_OP_CHAR, "a".ord], "a", 0)
      raise "expected invalid instruction length to fail"
    rescue ArgumentError
    end

    1_000.times do
      Regexpinel::Spinel.match_code?(Regexpinel.compile("a(b|c)d"), "acd", 0)
      Regexpinel::Spinel.new("a(b|c)d").match?("acd", 0)
    end
    GC.start
    Regexpinel::Spinel.new("ab").match?("ab", 0)

    puts "ok"
  end
end

SpinelExtensionTest.main
