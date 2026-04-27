#!/usr/bin/env ruby

require_relative "bench_helper"

CASES = [
  {
    label: "literal-ab",
    pattern: "ab",
    replacement: "X",
    inputs: ["zab"] * 1200 + ["abzab"] * 900 + ["zzz"] * 900
  },
  {
    label: "alternation-a-or-b",
    pattern: "a|b",
    replacement: "X",
    inputs: ["cab"] * 1000 + ["bbb"] * 1000 + ["ccc"] * 1000
  },
  {
    label: "group-alt",
    pattern: "a(b|c)d",
    replacement: "X",
    inputs: ["zabd"] * 800 + ["zacd"] * 800 + ["zaed"] * 800
  },
  {
    label: "wildcard-dot-b",
    pattern: ".b",
    replacement: "X",
    inputs: ["zab"] * 1000 + ["zzb"] * 1000 + ["zzz"] * 1000
  }
].freeze

loops = 200
if ARGV.length > 0
  loops = ARGV[0].to_i
end

rows = []

puts "Substitution benchmark"
puts "loops=#{loops}"

i = 0
while i < CASES.length
  c = CASES[i]

  nr_sub_elapsed, nr_sub_bytes = RegexpinelBench.bench_regexpinel_sub(c[:pattern], c[:inputs], c[:replacement], loops)
  spinel_sub_elapsed, spinel_sub_bytes = RegexpinelBench.bench_spinel_sub(c[:pattern], c[:inputs], c[:replacement], loops)
  cr_sub_elapsed, cr_sub_bytes = RegexpinelBench.bench_cruby_sub(c[:pattern], c[:inputs], c[:replacement], loops)

  nr_gsub_elapsed, nr_gsub_bytes = RegexpinelBench.bench_regexpinel_gsub(c[:pattern], c[:inputs], c[:replacement], loops)
  spinel_gsub_elapsed, spinel_gsub_bytes = RegexpinelBench.bench_spinel_gsub(c[:pattern], c[:inputs], c[:replacement], loops)
  cr_gsub_elapsed, cr_gsub_bytes = RegexpinelBench.bench_cruby_gsub(c[:pattern], c[:inputs], c[:replacement], loops)

  nr_sub_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, loops, nr_sub_elapsed)
  spinel_sub_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, loops, spinel_sub_elapsed)
  cr_sub_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, loops, cr_sub_elapsed)
  nr_gsub_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, loops, nr_gsub_elapsed)
  spinel_gsub_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, loops, spinel_gsub_elapsed)
  cr_gsub_checks = RegexpinelBench.checks_per_sec(c[:inputs].length, loops, cr_gsub_elapsed)

  puts
  puts "--- #{c[:label]} ---"
  puts "pattern: #{c[:pattern].inspect}"
  puts "replacement: #{c[:replacement].inspect}"
  puts "inputs: #{c[:inputs].length}"
  puts "regexpinel_sub_elapsed_s: #{nr_sub_elapsed}"
  puts "regexpinel_sub_ops_per_sec: #{nr_sub_checks}"
  puts "regexpinel_sub_bytes: #{nr_sub_bytes}"
  puts "spinel_sub_elapsed_s: #{spinel_sub_elapsed}"
  puts "spinel_sub_ops_per_sec: #{spinel_sub_checks}"
  puts "spinel_sub_bytes: #{spinel_sub_bytes}"
  puts "cruby_sub_elapsed_s: #{cr_sub_elapsed}"
  puts "cruby_sub_ops_per_sec: #{cr_sub_checks}"
  puts "cruby_sub_bytes: #{cr_sub_bytes}"
  puts "regexpinel_gsub_elapsed_s: #{nr_gsub_elapsed}"
  puts "regexpinel_gsub_ops_per_sec: #{nr_gsub_checks}"
  puts "regexpinel_gsub_bytes: #{nr_gsub_bytes}"
  puts "spinel_gsub_elapsed_s: #{spinel_gsub_elapsed}"
  puts "spinel_gsub_ops_per_sec: #{spinel_gsub_checks}"
  puts "spinel_gsub_bytes: #{spinel_gsub_bytes}"
  puts "cruby_gsub_elapsed_s: #{cr_gsub_elapsed}"
  puts "cruby_gsub_ops_per_sec: #{cr_gsub_checks}"
  puts "cruby_gsub_bytes: #{cr_gsub_bytes}"

  rows << {
    "label" => c[:label],
    "pattern" => c[:pattern],
    "replacement" => c[:replacement],
    "input_count" => c[:inputs].length,
    "loops" => loops,
    "regexpinel_sub_elapsed_s" => nr_sub_elapsed,
    "regexpinel_sub_ops_per_sec" => nr_sub_checks,
    "regexpinel_sub_bytes" => nr_sub_bytes,
    "spinel_sub_elapsed_s" => spinel_sub_elapsed,
    "spinel_sub_ops_per_sec" => spinel_sub_checks,
    "spinel_sub_bytes" => spinel_sub_bytes,
    "cruby_sub_elapsed_s" => cr_sub_elapsed,
    "cruby_sub_ops_per_sec" => cr_sub_checks,
    "cruby_sub_bytes" => cr_sub_bytes,
    "regexpinel_gsub_elapsed_s" => nr_gsub_elapsed,
    "regexpinel_gsub_ops_per_sec" => nr_gsub_checks,
    "regexpinel_gsub_bytes" => nr_gsub_bytes,
    "spinel_gsub_elapsed_s" => spinel_gsub_elapsed,
    "spinel_gsub_ops_per_sec" => spinel_gsub_checks,
    "spinel_gsub_bytes" => spinel_gsub_bytes,
    "cruby_gsub_elapsed_s" => cr_gsub_elapsed,
    "cruby_gsub_ops_per_sec" => cr_gsub_checks,
    "cruby_gsub_bytes" => cr_gsub_bytes
  }

  i += 1
end

path = RegexpinelBench.write_results("substitution", rows)
puts
puts "results_path=#{path}"
