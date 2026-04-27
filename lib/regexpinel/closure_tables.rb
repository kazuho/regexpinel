def nr_compute_closure(code, insn_count, start_pc)
  stack0 = start_pc
  stack1 = 0
  stack_top = 1
  visited = 0
  state_mask = 0
  matched = 0

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

    op = code[cur * 3]
    if op == NR_OP_JMP
      if stack_top == 0
        stack0 = code[cur * 3 + 1]
      else
        stack1 = code[cur * 3 + 1]
      end
      stack_top = stack_top + 1
    elsif op == NR_OP_SPLIT
      if stack_top == 0
        stack0 = code[cur * 3 + 1]
      else
        stack1 = code[cur * 3 + 1]
      end
      stack_top = stack_top + 1

      if stack_top == 0
        stack0 = code[cur * 3 + 2]
      else
        stack1 = code[cur * 3 + 2]
      end
      stack_top = stack_top + 1
    elsif op == NR_OP_MATCH
      matched = 1
    else
      state_mask = state_mask | bit
    end
  end

  [state_mask, matched]
end

def nr_compile_closure_tables(code)
  insn_count = code.length / 3
  closure_masks = Array.new(insn_count, 0)
  closure_matches = Array.new(insn_count, 0)
  pc = 0

  while pc < insn_count
    op = code[pc * 3]
    if op == NR_OP_CHAR
      result = nr_compute_closure(code, insn_count, code[pc * 3 + 2])
      closure_masks[pc] = result[0]
      closure_matches[pc] = result[1]
    elsif op == NR_OP_ANY
      result = nr_compute_closure(code, insn_count, code[pc * 3 + 1])
      closure_masks[pc] = result[0]
      closure_matches[pc] = result[1]
    end
    pc += 1
  end

  [closure_masks, closure_matches]
end
