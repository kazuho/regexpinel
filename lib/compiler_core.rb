require_relative "runtime"

NR_EOF = -1
$nr_pattern = ""
$nr_pos = 0
$nr_code = [0]
$nr_code.pop
$nr_ret_start = 0
$nr_ret_outs = [0]
$nr_ret_outs.pop

def nr_compile(pattern)
  $nr_pattern = pattern
  $nr_pos = 0
  $nr_code = [0]
  $nr_code.pop
  $nr_ret_start = 0
  $nr_ret_outs = [0]
  $nr_ret_outs.pop

  nr_parse_expression
  if $nr_pos != $nr_pattern.length
    raise "unexpected character at #{$nr_pos}"
  end

  start_pc = $nr_ret_start
  outs = $nr_ret_outs
  match_pc = nr_emit(NR_OP_MATCH, 0, 0)
  nr_patch(outs, match_pc)
  nr_normalize_start_pc(start_pc)
  0
end

def nr_parse_expression
  nr_parse_term
  left_start = $nr_ret_start
  left_outs = $nr_ret_outs

  while nr_peek == "|".ord
    nr_advance
    nr_parse_term
    right_start = $nr_ret_start
    right_outs = $nr_ret_outs
    split_pc = nr_emit(NR_OP_SPLIT, left_start, right_start)
    left_start = split_pc
    left_outs = nr_append_outs(left_outs, right_outs)
  end

  $nr_ret_start = left_start
  $nr_ret_outs = left_outs
  0
end

def nr_parse_term
  has_frag = false
  left_start = 0
  left_outs = [0]
  left_outs.pop

  while nr_more_term?
    nr_parse_factor
    part_start = $nr_ret_start
    part_outs = $nr_ret_outs

    if has_frag
      nr_patch(left_outs, part_start)
      left_outs = part_outs
    else
      has_frag = true
      left_start = part_start
      left_outs = part_outs
    end
  end

  if has_frag
    $nr_ret_start = left_start
    $nr_ret_outs = left_outs
  else
    jmp_pc = nr_emit(NR_OP_JMP, 0, 0)
    $nr_ret_start = jmp_pc
    $nr_ret_outs = [jmp_pc * 3 + 1]
  end
  0
end

def nr_parse_factor
  nr_parse_primary
  frag_start = $nr_ret_start
  frag_outs = $nr_ret_outs

  while true
    ch = nr_peek
    if ch == "*".ord
      nr_advance
      split_pc = nr_emit(NR_OP_SPLIT, frag_start, 0)
      nr_patch(frag_outs, split_pc)
      frag_start = split_pc
      frag_outs = [split_pc * 3 + 2]
    elsif ch == "+".ord
      nr_advance
      split_pc = nr_emit(NR_OP_SPLIT, frag_start, 0)
      nr_patch(frag_outs, split_pc)
      frag_outs = [split_pc * 3 + 2]
    elsif ch == "?".ord
      nr_advance
      split_pc = nr_emit(NR_OP_SPLIT, frag_start, 0)
      frag_start = split_pc
      frag_outs = nr_append_outs(frag_outs, [split_pc * 3 + 2])
    else
      $nr_ret_start = frag_start
      $nr_ret_outs = frag_outs
      return 0
    end
  end
end

def nr_parse_primary
  ch = nr_peek
  if ch == NR_EOF
    raise "unexpected end of pattern"
  end

  if ch == "(".ord
    nr_advance
    nr_parse_expression
    if nr_peek != ")".ord
      raise "unclosed group"
    end
    nr_advance
    return 0
  end

  if ch == ".".ord
    nr_advance
    pc = nr_emit(NR_OP_ANY, 0, 0)
    $nr_ret_start = pc
    $nr_ret_outs = [pc * 3 + 1]
    return 0
  end

  if ch == "\\".ord
    nr_advance
    esc = nr_peek
    if esc == NR_EOF
      raise "dangling escape"
    end
    nr_advance
    pc = nr_emit(NR_OP_CHAR, esc, 0)
    $nr_ret_start = pc
    $nr_ret_outs = [pc * 3 + 2]
    return 0
  end

  if ch == "|".ord || ch == ")".ord || ch == "*".ord || ch == "+".ord || ch == "?".ord
    raise "unexpected character #{ch.inspect}"
  end

  nr_advance
  pc = nr_emit(NR_OP_CHAR, ch, 0)
  $nr_ret_start = pc
  $nr_ret_outs = [pc * 3 + 2]
  0
end

def nr_emit(op, arg1, arg2)
  pc = $nr_code.length / 3
  $nr_code << op
  $nr_code << arg1
  $nr_code << arg2
  pc
end

def nr_patch(outs, target_pc)
  i = 0
  while i < outs.length
    $nr_code[outs[i]] = target_pc
    i += 1
  end
  0
end

def nr_append_outs(left, right)
  left + right
end

def nr_normalize_start_pc(start_pc)
  return 0 if start_pc == 0

  old_code = $nr_code
  new_code = [NR_OP_JMP, start_pc + 1, 0]
  pc = 0
  while pc < old_code.length / 3
    base = pc * 3
    op = old_code[base]
    a1 = old_code[base + 1]
    a2 = old_code[base + 2]

    if op == NR_OP_CHAR
      a2 += 1
    elsif op == NR_OP_ANY
      a1 += 1
    elsif op == NR_OP_JMP
      a1 += 1
    elsif op == NR_OP_SPLIT
      a1 += 1
      a2 += 1
    end

    new_code << op
    new_code << a1
    new_code << a2
    pc += 1
  end
  $nr_code = new_code
  0
end

def nr_more_term?
  ch = nr_peek
  return false if ch == NR_EOF
  return false if ch == "|".ord || ch == ")".ord
  true
end

def nr_peek
  return NR_EOF if $nr_pos >= $nr_pattern.length
  $nr_pattern.getbyte($nr_pos)
end

def nr_advance
  $nr_pos = $nr_pos + 1
  0
end
