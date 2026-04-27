#!/usr/bin/env ruby

require_relative "../lib/compiler"

$nr_compat_last_match = false

def nr_on_match(start_pos, end_pos, capture_count)
  $nr_compat_last_match = true
  0
end

module CompatMatchTest
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
  ]

  module_function

  def assert_eq(actual, expected, label)
    return if actual == expected
    raise "FAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
  end

  def run_regexpinel(pattern, input, start_pos)
    code = Regexpinel.compile(pattern)
    insn_count = code.length / 3
    current_states = Array.new(insn_count, 0)
    next_states = Array.new(insn_count, 0)
    mark_tokens = Array.new(insn_count, 0)
    epsilon_stack = Array.new(insn_count, 0)
    mark_token_box = [0]
    $nr_compat_last_match = false
    nr_match(code, input, start_pos, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
  end

  def main
    i = 0
    while i < CASES.length
      pattern = CASES[i][0]
      input = CASES[i][1]
      start_pos = CASES[i][2]
      expected = input.match?(Regexp.new(pattern), start_pos)
      actual = run_regexpinel(pattern, input, start_pos)
      assert_eq(actual, expected, "compat #{pattern.inspect} on #{input.inspect} at #{start_pos}")
      if actual
        assert_eq($nr_compat_last_match, true, "callback fired for #{pattern.inspect}")
      end
      i += 1
    end
    puts "ok"
  end
end

CompatMatchTest.main
