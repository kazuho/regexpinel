#!/usr/bin/env ruby

require_relative "../lib/runtime"

$nr_last_start = -1
$nr_last_end = -1
$nr_last_capture_count = -1

def nr_on_match(start_pos, end_pos, capture_count)
  $nr_last_start = start_pos
  $nr_last_end = end_pos
  $nr_last_capture_count = capture_count
  0
end

module ExecutorTest
  OP_CHAR = NR_OP_CHAR
  OP_ANY = NR_OP_ANY
  OP_JMP = NR_OP_JMP
  OP_SPLIT = NR_OP_SPLIT
  OP_MATCH = NR_OP_MATCH

  module_function

  def assert_eq(actual, expected, label)
    return if actual == expected
    raise "FAIL #{label}: expected #{expected.inspect}, got #{actual.inspect}"
  end

  def run_match(code, string, start_pos = 0)
    $nr_last_start = -1
    $nr_last_end = -1
    $nr_last_capture_count = -1
    insn_count = code.length / 3
    current_states = Array.new(insn_count, 0)
    next_states = Array.new(insn_count, 0)
    mark_tokens = Array.new(insn_count, 0)
    epsilon_stack = Array.new(insn_count, 0)
    mark_token_box = [0]
    nr_match(code, string, start_pos, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
  end

  def prog_ab
    [
      OP_CHAR, "a".ord, 1,
      OP_CHAR, "b".ord, 2,
      OP_MATCH, 0, 0
    ]
  end

  def prog_a_or_b
    [
      OP_SPLIT, 1, 2,
      OP_CHAR, "a".ord, 3,
      OP_CHAR, "b".ord, 3,
      OP_MATCH, 0, 0
    ]
  end

  def prog_a_star_b
    [
      OP_SPLIT, 1, 3,
      OP_CHAR, "a".ord, 2,
      OP_JMP, 0, 0,
      OP_CHAR, "b".ord, 4,
      OP_MATCH, 0, 0
    ]
  end

  def prog_any_b
    [
      OP_ANY, 1, 0,
      OP_CHAR, "b".ord, 2,
      OP_MATCH, 0, 0
    ]
  end

  def main
    assert_eq(run_match(prog_ab, "ab"), true, "ab matches ab")
    assert_eq($nr_last_start, 0, "ab callback start")
    assert_eq($nr_last_end, 2, "ab callback end")
    assert_eq(run_match(prog_ab, "ac"), false, "ab rejects ac")
    assert_eq(run_match(prog_ab, "zab", 1), true, "ab matches at offset 1")
    assert_eq($nr_last_start, 1, "offset callback start")
    assert_eq($nr_last_end, 3, "offset callback end")

    assert_eq(run_match(prog_a_or_b, "a"), true, "a|b matches a")
    assert_eq(run_match(prog_a_or_b, "b"), true, "a|b matches b")
    assert_eq(run_match(prog_a_or_b, "c"), false, "a|b rejects c")

    assert_eq(run_match(prog_a_star_b, "b"), true, "a*b matches b")
    assert_eq(run_match(prog_a_star_b, "aaab"), true, "a*b matches aaab")
    assert_eq(run_match(prog_a_star_b, "aaac"), false, "a*b rejects aaac")

    assert_eq(run_match(prog_any_b, "ab"), true, ".b matches ab")
    assert_eq(run_match(prog_any_b, "zb"), true, ".b matches zb")
    assert_eq(run_match(prog_any_b, "zz"), false, ".b rejects zz")

    puts "ok"
  end
end

ExecutorTest.main
