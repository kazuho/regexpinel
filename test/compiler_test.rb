#!/usr/bin/env ruby

require_relative "../lib/compiler"

module CompilerTest
  module_function

  def assert_eq(actual, expected, label)
    return if actual == expected
    raise "FAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
  end

  def test_exact_bytecode
    assert_eq(
      Regexpinel.compile("ab"),
      [
        NR_OP_CHAR, "a".ord, 1,
        NR_OP_CHAR, "b".ord, 2,
        NR_OP_MATCH, 0, 0
      ],
      "compile ab"
    )

    assert_eq(
      Regexpinel.compile("a|b"),
      [
        NR_OP_JMP, 3, 0,
        NR_OP_CHAR, "a".ord, 4,
        NR_OP_CHAR, "b".ord, 4,
        NR_OP_SPLIT, 1, 2,
        NR_OP_MATCH, 0, 0
      ],
      "compile a|b"
    )

    assert_eq(
      Regexpinel.compile("a*"),
      [
        NR_OP_JMP, 2, 0,
        NR_OP_CHAR, "a".ord, 2,
        NR_OP_SPLIT, 1, 3,
        NR_OP_MATCH, 0, 0
      ],
      "compile a*"
    )
  end

  def main
    test_exact_bytecode
    puts "ok"
  end
end

CompilerTest.main
