require_relative "core"

$nr_bytecode_code = []
$nr_bytecode_insn_count = 0

def nr_core_insn_count
  $nr_bytecode_insn_count
end

def nr_core_op(pc)
  $nr_bytecode_code[pc * 3]
end

def nr_core_arg1(pc)
  $nr_bytecode_code[pc * 3 + 1]
end

def nr_core_arg2(pc)
  $nr_bytecode_code[pc * 3 + 2]
end

def nr_make_context(insn_count)
  [insn_count]
end

def nr_match(code, string, start_pos, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
  code.length
  string.length
  $nr_bytecode_code = code
  $nr_bytecode_insn_count = code.length / 3
  nr_core_match(string, string.bytesize, start_pos)
end
