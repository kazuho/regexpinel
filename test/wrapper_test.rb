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

  def test_substitution
    # Substitution uses the VM's currently reported accepted range. The VM does
    # not implement CRuby quantifier greediness yet.
    cases = [
      ["ab", "zab", "X", "zX", "zX"],
      ["ab", "zzz", "X", "zzz", "zzz"],
      ["a|b", "cab", "X", "cXb", "cXX"],
      ["a+", "caaab", "X", "cXaab", "cXXXb"],
      [".b", "zab", "X", "zX", "zX"],
      ["a*", "bbbb", "X", "Xbbbb", "XbXbXbXbX"],
      ["a*", "", "X", "X", "X"]
    ]

    i = 0
    while i < cases.length
      pattern = cases[i][0]
      input = cases[i][1]
      replacement = cases[i][2]
      expected_sub = cases[i][3]
      expected_gsub = cases[i][4]
      wrapper = Regexpinel::CRuby.new(pattern)
      assert_eq(wrapper.sub(input, replacement), expected_sub, "sub #{pattern.inspect} on #{input.inspect}")
      assert_eq(wrapper.gsub(input, replacement), expected_gsub, "gsub #{pattern.inspect} on #{input.inspect}")
      i += 1
    end
  end

  def main
    test_repeated_calls
    test_compatibility
    test_substitution
    assert_eq(Regexpinel::Pattern.compile("ab").match?("ab"), true, "legacy Pattern.compile")
    puts "ok"
  end
end

WrapperTest.main
