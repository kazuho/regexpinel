#!/usr/bin/env ruby

require_relative "bench_helper"

CASES = [
  {
    label: "long-star-literal-match",
    pattern: "z*ab",
    replacement: "X",
    inputs: [("z" * 1024) + "ab"] * 200
  },
  {
    label: "long-star-literal-miss",
    pattern: "z*ab",
    replacement: "X",
    inputs: [("z" * 1024) + "ac"] * 200
  },
  {
    label: "long-plus-match",
    pattern: "a+b",
    replacement: "X",
    inputs: [("a" * 1024) + "b"] * 200
  },
  {
    label: "long-plus-miss",
    pattern: "a+b",
    replacement: "X",
    inputs: [("a" * 1024) + "c"] * 200
  },
  {
    label: "long-utf8-dot-match",
    pattern: "é*x",
    replacement: "X",
    inputs: [("é" * 512) + "x"] * 200
  }
].freeze

loops = 50
if ARGV.length > 0
  loops = ARGV[0].to_i
end

def mib_per_sec(bytes, elapsed)
  return 0.0 if elapsed <= 0.0
  bytes / elapsed / (1024.0 * 1024.0)
end

def run_match_bench(label, compiled, inputs, loops)
  started = RegexpinelBench.now_seconds
  matches = 0
  loop_i = 0
  while loop_i < loops
    i = 0
    while i < inputs.length
      matches += 1 if compiled.match?(inputs[i])
      i += 1
    end
    loop_i += 1
  end
  [RegexpinelBench.now_seconds - started, matches]
end

rows = []

RegexpinelBench.ensure_spinel_extension

puts "Long-input benchmark"
puts "loops=#{loops}"

i = 0
while i < CASES.length
  c = CASES[i]
  input_bytes = 0
  j = 0
  while j < c[:inputs].length
    input_bytes += c[:inputs][j].bytesize
    j += 1
  end
  total_bytes = input_bytes * loops

  nr = Regexpinel::CRuby.new(c[:pattern])
  spinel = Regexpinel::Spinel.new(c[:pattern])
  cr_re = Regexp.new("\\A(?:#{c[:pattern]})")

  c[:inputs].each do |input|
    expected = cr_re.match?(input)
    unless nr.match?(input) == expected && spinel.match?(input) == expected
      raise "match mismatch for #{c[:label]} on #{input.inspect}"
    end
  end

  nr_elapsed, nr_matches = run_match_bench("regexpinel", nr, c[:inputs], loops)
  spinel_elapsed, spinel_matches = run_match_bench("spinel", spinel, c[:inputs], loops)
  cr_started = RegexpinelBench.now_seconds
  cr_matches = 0
  loop_i = 0
  while loop_i < loops
    input_i = 0
    while input_i < c[:inputs].length
      cr_matches += 1 if cr_re.match?(c[:inputs][input_i])
      input_i += 1
    end
    loop_i += 1
  end
  cr_elapsed = RegexpinelBench.now_seconds - cr_started

  puts
  puts "--- #{c[:label]} ---"
  puts "pattern: #{c[:pattern].inspect}"
  puts "inputs: #{c[:inputs].length}"
  puts "input_bytes_per_loop: #{input_bytes}"
  puts "total_bytes: #{total_bytes}"
  puts "regexpinel_elapsed_s: #{nr_elapsed}"
  puts "regexpinel_ops_per_sec: #{RegexpinelBench.checks_per_sec(c[:inputs].length, loops, nr_elapsed)}"
  puts "regexpinel_mib_per_sec: #{mib_per_sec(total_bytes, nr_elapsed)}"
  puts "regexpinel_matches: #{nr_matches}"
  puts "spinel_elapsed_s: #{spinel_elapsed}"
  puts "spinel_ops_per_sec: #{RegexpinelBench.checks_per_sec(c[:inputs].length, loops, spinel_elapsed)}"
  puts "spinel_mib_per_sec: #{mib_per_sec(total_bytes, spinel_elapsed)}"
  puts "spinel_matches: #{spinel_matches}"
  puts "cruby_elapsed_s: #{cr_elapsed}"
  puts "cruby_ops_per_sec: #{RegexpinelBench.checks_per_sec(c[:inputs].length, loops, cr_elapsed)}"
  puts "cruby_mib_per_sec: #{mib_per_sec(total_bytes, cr_elapsed)}"
  puts "cruby_matches: #{cr_matches}"

  rows << {
    "label" => c[:label],
    "pattern" => c[:pattern],
    "input_count" => c[:inputs].length,
    "input_bytes_per_loop" => input_bytes,
    "loops" => loops,
    "total_bytes" => total_bytes,
    "regexpinel_elapsed_s" => nr_elapsed,
    "regexpinel_mib_per_sec" => mib_per_sec(total_bytes, nr_elapsed),
    "regexpinel_matches" => nr_matches,
    "spinel_elapsed_s" => spinel_elapsed,
    "spinel_mib_per_sec" => mib_per_sec(total_bytes, spinel_elapsed),
    "spinel_matches" => spinel_matches,
    "cruby_elapsed_s" => cr_elapsed,
    "cruby_mib_per_sec" => mib_per_sec(total_bytes, cr_elapsed),
    "cruby_matches" => cr_matches
  }

  i += 1
end

path = RegexpinelBench.write_results("long_inputs", rows)
puts
puts "results_path=#{path}"
