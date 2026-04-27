#!/usr/bin/env ruby

require_relative "bench_helper"

CASES = [
  {
    label: "literal-ab",
    pattern: "ab",
    inputs: ["ab"] * 2000 + ["ac"] * 1000
  },
  {
    label: "alternation-a-or-b",
    pattern: "a|b",
    inputs: ["a"] * 1000 + ["b"] * 1000 + ["c"] * 1000
  },
  {
    label: "kleene-a-star",
    pattern: "a*",
    inputs: [""] * 500 + ["aaaa"] * 1500 + ["bbbb"] * 1000
  },
  {
    label: "plus-a-plus-b",
    pattern: "a+b",
    inputs: ["ab"] * 500 + ["aaab"] * 1000 + ["b"] * 1000
  },
  {
    label: "optional-ab-q",
    pattern: "ab?",
    inputs: ["a"] * 1000 + ["ab"] * 1000 + ["ac"] * 1000
  },
  {
    label: "group-alt",
    pattern: "a(b|c)d",
    inputs: ["abd"] * 800 + ["acd"] * 800 + ["aed"] * 800
  },
  {
    label: "wildcard-dot-b",
    pattern: ".b",
    inputs: ["ab"] * 1000 + ["zb"] * 1000 + ["zz"] * 1000
  }
].freeze

compile_loops = 2000
match_loops = 300
if ARGV.length > 0
  compile_loops = ARGV[0].to_i
end
if ARGV.length > 1
  match_loops = ARGV[1].to_i
end

rows = []

puts "Synthetic benchmark"
puts "compile_loops=#{compile_loops}"
puts "match_loops=#{match_loops}"

i = 0
while i < CASES.length
  c = CASES[i]
  compile_elapsed = RegexpinelBench.bench_compile(c[:pattern], compile_loops)
  nr_elapsed, nr_matches = RegexpinelBench.bench_regexpinel_match(c[:pattern], c[:inputs], match_loops)
  spinel_elapsed, spinel_matches = RegexpinelBench.bench_spinel_match(c[:pattern], c[:inputs], match_loops)
  cr_elapsed, cr_matches = RegexpinelBench.bench_cruby_match(c[:pattern], c[:inputs], match_loops)

  nr_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, match_loops, nr_elapsed)
  spinel_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, match_loops, spinel_elapsed)
  cr_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, match_loops, cr_elapsed)

  puts
  puts "--- #{c[:label]} ---"
  puts "pattern: #{c[:pattern].inspect}"
  puts "inputs: #{c[:inputs].length}"
  puts "compile_elapsed_s: #{compile_elapsed}"
  puts "regexpinel_elapsed_s: #{nr_elapsed}"
  puts "regexpinel_checks_per_sec: #{nr_checks}"
  puts "regexpinel_matches: #{nr_matches}"
  puts "spinel_elapsed_s: #{spinel_elapsed}"
  puts "spinel_checks_per_sec: #{spinel_checks}"
  puts "spinel_matches: #{spinel_matches}"
  puts "cruby_elapsed_s: #{cr_elapsed}"
  puts "cruby_checks_per_sec: #{cr_checks}"
  puts "cruby_matches: #{cr_matches}"

  rows << {
    "label" => c[:label],
    "pattern" => c[:pattern],
    "input_count" => c[:inputs].length,
    "compile_loops" => compile_loops,
    "compile_elapsed_s" => compile_elapsed,
    "match_loops" => match_loops,
    "regexpinel_elapsed_s" => nr_elapsed,
    "regexpinel_checks_per_sec" => nr_checks,
    "regexpinel_matches" => nr_matches,
    "spinel_elapsed_s" => spinel_elapsed,
    "spinel_checks_per_sec" => spinel_checks,
    "spinel_matches" => spinel_matches,
    "cruby_elapsed_s" => cr_elapsed,
    "cruby_checks_per_sec" => cr_checks,
    "cruby_matches" => cr_matches
  }

  i += 1
end

path = RegexpinelBench.write_results("synthetic", rows)
puts
puts "results_path=#{path}"
