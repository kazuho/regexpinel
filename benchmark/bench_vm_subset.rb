#!/usr/bin/env ruby

require_relative "../lib/runtime"

def nr_on_match(start_pos, end_pos, capture_count)
  0
end

loops = 500000
if ARGV.length > 0
  loops = ARGV[0].to_i
end

puts "mode,vm_subset"
puts "loops,#{loops}"

code = [1, 97, 1, 1, 98, 2, 5, 0, 0]
insn_count = code.length / 3
current_states = Array.new(insn_count, 0)
next_states = Array.new(insn_count, 0)
mark_tokens = Array.new(insn_count, 0)
epsilon_stack = Array.new(insn_count, 0)
mark_token_box = [0]
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if nr_match(code, "ab", 0, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,literal-ab-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

code = [1, 97, 1, 1, 98, 2, 5, 0, 0]
insn_count = code.length / 3
current_states = Array.new(insn_count, 0)
next_states = Array.new(insn_count, 0)
mark_tokens = Array.new(insn_count, 0)
epsilon_stack = Array.new(insn_count, 0)
mark_token_box = [0]
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if nr_match(code, "ac", 0, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,literal-ab-miss,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

code = [3, 3, 0, 1, 97, 4, 1, 98, 4, 4, 1, 2, 5, 0, 0]
insn_count = code.length / 3
current_states = Array.new(insn_count, 0)
next_states = Array.new(insn_count, 0)
mark_tokens = Array.new(insn_count, 0)
epsilon_stack = Array.new(insn_count, 0)
mark_token_box = [0]
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if nr_match(code, "b", 0, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,alternation-a-or-b-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

code = [3, 2, 0, 1, 97, 2, 4, 1, 3, 5, 0, 0]
insn_count = code.length / 3
current_states = Array.new(insn_count, 0)
next_states = Array.new(insn_count, 0)
mark_tokens = Array.new(insn_count, 0)
epsilon_stack = Array.new(insn_count, 0)
mark_token_box = [0]
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if nr_match(code, "aaaa", 0, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,kleene-a-star-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"

code = [1, 97, 3, 1, 98, 4, 1, 99, 4, 4, 1, 2, 1, 100, 5, 5, 0, 0]
insn_count = code.length / 3
current_states = Array.new(insn_count, 0)
next_states = Array.new(insn_count, 0)
mark_tokens = Array.new(insn_count, 0)
epsilon_stack = Array.new(insn_count, 0)
mark_token_box = [0]
started = Time.now.to_f
matches = 0
i = 0
while i < loops
  if nr_match(code, "acd", 0, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
    matches += 1
  end
  i += 1
end
elapsed = Time.now.to_f - started
puts "case,group-alt-match,1,#{loops},#{elapsed},#{loops / elapsed},#{matches}"
