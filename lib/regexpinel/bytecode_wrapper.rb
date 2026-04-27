require_relative "core"

$nr_bytecode_code = []
$nr_bytecode_insn_count = 0
$nr_bytecode_closure_masks = ""
$nr_bytecode_closure_matches = ""
$nr_bytecode_ret_mask = 0
$nr_bytecode_ret_match = 0

NR_BYTECODE_META_SLOT_SIZE = 8

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

def nr_core_closure_mask(pc)
  nr_bytecode_read_closure_mask(pc)
end

def nr_core_closure_match(pc)
  nr_bytecode_read_closure_match(pc)
end

def nr_make_context(insn_count)
  [insn_count]
end

def nr_bytecode_write_closure_mask(pc, value)
  offset = pc * NR_BYTECODE_META_SLOT_SIZE
  $nr_bytecode_closure_masks.setbyte(offset, value & 255)
  $nr_bytecode_closure_masks.setbyte(offset + 1, (value >> 8) & 255)
  $nr_bytecode_closure_masks.setbyte(offset + 2, (value >> 16) & 255)
  $nr_bytecode_closure_masks.setbyte(offset + 3, (value >> 24) & 255)
  $nr_bytecode_closure_masks.setbyte(offset + 4, (value >> 32) & 255)
  $nr_bytecode_closure_masks.setbyte(offset + 5, (value >> 40) & 255)
  $nr_bytecode_closure_masks.setbyte(offset + 6, (value >> 48) & 255)
  $nr_bytecode_closure_masks.setbyte(offset + 7, (value >> 56) & 255)
  0
end

def nr_bytecode_write_closure_match(pc, value)
  offset = pc * NR_BYTECODE_META_SLOT_SIZE
  $nr_bytecode_closure_matches.setbyte(offset, value & 255)
  $nr_bytecode_closure_matches.setbyte(offset + 1, (value >> 8) & 255)
  $nr_bytecode_closure_matches.setbyte(offset + 2, (value >> 16) & 255)
  $nr_bytecode_closure_matches.setbyte(offset + 3, (value >> 24) & 255)
  $nr_bytecode_closure_matches.setbyte(offset + 4, (value >> 32) & 255)
  $nr_bytecode_closure_matches.setbyte(offset + 5, (value >> 40) & 255)
  $nr_bytecode_closure_matches.setbyte(offset + 6, (value >> 48) & 255)
  $nr_bytecode_closure_matches.setbyte(offset + 7, (value >> 56) & 255)
  0
end

def nr_bytecode_read_closure_mask(pc)
  offset = pc * NR_BYTECODE_META_SLOT_SIZE
  b0 = $nr_bytecode_closure_masks.getbyte(offset)
  b1 = $nr_bytecode_closure_masks.getbyte(offset + 1)
  b2 = $nr_bytecode_closure_masks.getbyte(offset + 2)
  b3 = $nr_bytecode_closure_masks.getbyte(offset + 3)
  b4 = $nr_bytecode_closure_masks.getbyte(offset + 4)
  b5 = $nr_bytecode_closure_masks.getbyte(offset + 5)
  b6 = $nr_bytecode_closure_masks.getbyte(offset + 6)
  b7 = $nr_bytecode_closure_masks.getbyte(offset + 7)
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24) | (b4 << 32) | (b5 << 40) | (b6 << 48) | (b7 << 56)
end

def nr_bytecode_read_closure_match(pc)
  offset = pc * NR_BYTECODE_META_SLOT_SIZE
  b0 = $nr_bytecode_closure_matches.getbyte(offset)
  b1 = $nr_bytecode_closure_matches.getbyte(offset + 1)
  b2 = $nr_bytecode_closure_matches.getbyte(offset + 2)
  b3 = $nr_bytecode_closure_matches.getbyte(offset + 3)
  b4 = $nr_bytecode_closure_matches.getbyte(offset + 4)
  b5 = $nr_bytecode_closure_matches.getbyte(offset + 5)
  b6 = $nr_bytecode_closure_matches.getbyte(offset + 6)
  b7 = $nr_bytecode_closure_matches.getbyte(offset + 7)
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24) | (b4 << 32) | (b5 << 40) | (b6 << 48) | (b7 << 56)
end

def nr_bytecode_compute_closure(start_pc)
  stack0 = start_pc
  stack1 = 0
  stack_top = 1
  visited = 0
  state_mask = 0
  $nr_bytecode_ret_match = 0

  while stack_top > 0
    stack_top = stack_top - 1
    if stack_top == 0
      cur = stack0
    else
      cur = stack1
    end

    bit = 1 << cur
    if (visited & bit) != 0
      next
    end
    visited = visited | bit

    op = nr_core_op(cur)
    if op == NR_OP_JMP
      if stack_top == 0
        stack0 = nr_core_arg1(cur)
      else
        stack1 = nr_core_arg1(cur)
      end
      stack_top = stack_top + 1
    elsif op == NR_OP_SPLIT
      if stack_top == 0
        stack0 = nr_core_arg1(cur)
      else
        stack1 = nr_core_arg1(cur)
      end
      stack_top = stack_top + 1

      if stack_top == 0
        stack0 = nr_core_arg2(cur)
      else
        stack1 = nr_core_arg2(cur)
      end
      stack_top = stack_top + 1
    elsif op == NR_OP_MATCH
      $nr_bytecode_ret_match = 1
    else
      state_mask = state_mask | bit
    end
  end

  $nr_bytecode_ret_mask = state_mask
  0
end

def nr_bytecode_install_closure_tables(code)
  insn_count = code.length / 3
  $nr_bytecode_closure_masks = "\0" * (insn_count * NR_BYTECODE_META_SLOT_SIZE)
  $nr_bytecode_closure_matches = "\0" * (insn_count * NR_BYTECODE_META_SLOT_SIZE)

  pc = 0
  while pc < insn_count
    op = nr_core_op(pc)
    if op == NR_OP_CHAR
      nr_bytecode_compute_closure(nr_core_arg2(pc))
      nr_bytecode_write_closure_mask(pc, $nr_bytecode_ret_mask)
      nr_bytecode_write_closure_match(pc, $nr_bytecode_ret_match)
    elsif op == NR_OP_ANY
      nr_bytecode_compute_closure(nr_core_arg1(pc))
      nr_bytecode_write_closure_mask(pc, $nr_bytecode_ret_mask)
      nr_bytecode_write_closure_match(pc, $nr_bytecode_ret_match)
    else
      nr_bytecode_write_closure_mask(pc, 0)
      nr_bytecode_write_closure_match(pc, 0)
    end
    pc += 1
  end
  0
end

def nr_match(code, string, start_pos, current_states, next_states, mark_tokens, epsilon_stack, mark_token_box)
  code.length
  string.length
  $nr_bytecode_code = code
  $nr_bytecode_insn_count = code.length / 3
  nr_bytecode_install_closure_tables(code)
  nr_core_match(string, string.bytesize, start_pos)
end
