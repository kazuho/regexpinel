#!/usr/bin/env ruby

require_relative "../lib/regexpinel/bytecode_wrapper"

def nr_on_match(start_pos, end_pos, capture_count)
  print "match,"
  print start_pos
  print ","
  print end_pos
  print ","
  puts capture_count
  0
end

if ARGV.length < 2
  $stderr.puts "usage: ruby bin/run_vm.rb OPCODE_CSV INPUT [START_POS]"
  exit 1
end

parts = ARGV[0].split(",")
code = []
i = 0
while i < parts.length
  code << parts[i].to_i
  i += 1
end
input = ARGV[1]
start_pos = 0
if ARGV.length > 2
  start_pos = ARGV[2].to_i
end

insn_count = code.length / 3
current_states = Array.new(insn_count, 0)
next_states = Array.new(insn_count, 0)
mark_tokens = Array.new(insn_count, 0)
epsilon_stack = Array.new(insn_count, 0)
mark_token_box = [0]

matched = nr_match(code, input, start_pos, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)

if matched
  puts "status,1"
else
  puts "status,0"
end
