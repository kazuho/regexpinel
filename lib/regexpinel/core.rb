NR_OP_CHAR = 1
NR_OP_ANY = 2
NR_OP_JMP = 3
NR_OP_SPLIT = 4
NR_OP_MATCH = 5

def nr_core_add_state(pc, state_mask)
  stack0 = pc
  stack1 = 0
  stack_top = 1
  visited = 0
  matched = 0
  match_bit = 1 << nr_core_insn_count

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
      matched = 1
    else
      state_mask = state_mask | bit
    end
  end

  if matched != 0
    state_mask = state_mask | match_bit
  end

  state_mask
end

def nr_core_match(input, start_pos)
  match_bit = 1 << nr_core_insn_count
  state_mask = match_bit - 1
  add_result = nr_core_add_state(0, 0)
  current_mask = add_result & state_mask
  if (add_result & match_bit) != 0
    nr_on_match(start_pos, start_pos, 0)
    return true
  end

  pos = start_pos
  while pos < input.length
    byte = input.getbyte(pos)
    next_mask = 0
    matched = 0
    pc = 0
    while pc < nr_core_insn_count
      bit = 1 << pc
      if (current_mask & bit) != 0
        op = nr_core_op(pc)
        if op == NR_OP_CHAR
          if byte == nr_core_arg1(pc)
            add_result = nr_core_add_state(nr_core_arg2(pc), next_mask)
            next_mask = add_result & state_mask
            if (add_result & match_bit) != 0
              matched = 1
            end
          end
        elsif op == NR_OP_ANY
          add_result = nr_core_add_state(nr_core_arg1(pc), next_mask)
          next_mask = add_result & state_mask
          if (add_result & match_bit) != 0
            matched = 1
          end
        end
      end
      pc = pc + 1
    end

    if matched != 0
      nr_on_match(start_pos, pos + 1, 0)
      return true
    end
    if next_mask == 0
      return false
    end
    current_mask = next_mask
    pos = pos + 1
  end

  false
end
