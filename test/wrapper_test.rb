#!/usr/bin/env ruby

require_relative "../lib/regexpinel"

module WrapperTest
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

  def test_repeated_calls
    pat = Regexpinel::CRuby.new("a+b")
    assert_eq(pat.match?("aaab"), true, "first repeated call")
    assert_eq(pat.match?("b"), false, "second repeated call")
    assert_eq(pat.match?("aaaaab"), true, "third repeated call")
    assert_eq(pat.instruction_count > 0, true, "instruction_count")
  end

  def test_compatibility
    i = 0
    while i < CASES.length
      pattern = CASES[i][0]
      input = CASES[i][1]
      start_pos = CASES[i][2]
      wrapper = Regexpinel::CRuby.new(pattern)
      actual = wrapper.match?(input, start_pos)
      expected = input.match?(Regexp.new(pattern), start_pos)
      assert_eq(actual, expected, "wrapper compat #{pattern.inspect} on #{input.inspect} at #{start_pos}")
      i += 1
    end
  end

  def main
    test_repeated_calls
    test_compatibility
    assert_eq(Regexpinel::Pattern.compile("ab").match?("ab"), true, "legacy Pattern.compile")
    puts "ok"
  end
end

WrapperTest.main
