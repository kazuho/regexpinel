#!/usr/bin/env ruby

require_relative "../lib/regexpinel/core"

NR_PROOF_MAX_INSNS = 64
NR_PROOF_SLOT_SIZE = 12
NR_PROOF_BUFFER_SIZE = NR_PROOF_MAX_INSNS * NR_PROOF_SLOT_SIZE
NR_PROOF_META_SLOT_SIZE = 4
NR_PROOF_META_BUFFER_SIZE = NR_PROOF_MAX_INSNS * NR_PROOF_META_SLOT_SIZE

$nr_proof_code = "\1" * NR_PROOF_BUFFER_SIZE
$nr_proof_insn_count = 0
$nr_proof_closure_masks = "\0" * NR_PROOF_META_BUFFER_SIZE
$nr_proof_closure_matches = "\0" * NR_PROOF_META_BUFFER_SIZE
$nr_proof_ret_mask = 0
$nr_proof_ret_match = 0

def nr_on_match(start_pos, end_pos, capture_count)
  print "match,"
  print start_pos
  print ","
  print end_pos
  print ","
  puts capture_count
  0
end

def nr_core_insn_count
  $nr_proof_insn_count
end

def nr_proof_slot_offset(field_index)
  field_index * 4
end

def nr_proof_write_field(field_index, value)
  offset = nr_proof_slot_offset(field_index)
  $nr_proof_code.setbyte(offset, value & 255)
  $nr_proof_code.setbyte(offset + 1, (value >> 8) & 255)
  $nr_proof_code.setbyte(offset + 2, (value >> 16) & 255)
  $nr_proof_code.setbyte(offset + 3, (value >> 24) & 255)
  0
end

def nr_proof_read_field(field_index)
  offset = nr_proof_slot_offset(field_index)
  b0 = $nr_proof_code.getbyte(offset)
  b1 = $nr_proof_code.getbyte(offset + 1)
  b2 = $nr_proof_code.getbyte(offset + 2)
  b3 = $nr_proof_code.getbyte(offset + 3)
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
end

def nr_proof_write_meta(buffer, pc, value)
  offset = pc * NR_PROOF_META_SLOT_SIZE
  buffer.setbyte(offset, value & 255)
  buffer.setbyte(offset + 1, (value >> 8) & 255)
  buffer.setbyte(offset + 2, (value >> 16) & 255)
  buffer.setbyte(offset + 3, (value >> 24) & 255)
  0
end

def nr_proof_read_meta(buffer, pc)
  offset = pc * NR_PROOF_META_SLOT_SIZE
  b0 = buffer.getbyte(offset)
  b1 = buffer.getbyte(offset + 1)
  b2 = buffer.getbyte(offset + 2)
  b3 = buffer.getbyte(offset + 3)
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
end

def nr_proof_compute_closure(start_pc)
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

  $nr_proof_ret_mask = state_mask
  $nr_proof_ret_match = matched
  0
end

def nr_proof_compile_closures
  pc = 0
  while pc < $nr_proof_insn_count
    nr_proof_write_meta($nr_proof_closure_masks, pc, 0)
    nr_proof_write_meta($nr_proof_closure_matches, pc, 0)

    op = nr_core_op(pc)
    if op == NR_OP_CHAR
      nr_proof_compute_closure(nr_core_arg2(pc))
      nr_proof_write_meta($nr_proof_closure_masks, pc, $nr_proof_ret_mask)
      nr_proof_write_meta($nr_proof_closure_matches, pc, $nr_proof_ret_match)
    elsif op == NR_OP_ANY
      nr_proof_compute_closure(nr_core_arg1(pc))
      nr_proof_write_meta($nr_proof_closure_masks, pc, $nr_proof_ret_mask)
      nr_proof_write_meta($nr_proof_closure_matches, pc, $nr_proof_ret_match)
    end

    pc += 1
  end
  0
end

def nr_proof_decode_code(code_csv)
  pos = 0
  field_index = 0
  value = 0
  have_digit = 0

  while pos < code_csv.length
    byte = code_csv.getbyte(pos)
    if byte >= 48 && byte <= 57
      value = value * 10 + byte - 48
      have_digit = 1
    elsif byte == 44
      nr_proof_write_field(field_index, value)
      field_index = field_index + 1
      value = 0
      have_digit = 0
    end
    pos = pos + 1
  end

  if have_digit != 0
    nr_proof_write_field(field_index, value)
    field_index = field_index + 1
  end

  $nr_proof_insn_count = field_index / 3
  nr_proof_compile_closures
  0
end

def nr_core_op(pc)
  nr_proof_read_field(pc * 3)
end

def nr_core_arg1(pc)
  nr_proof_read_field(pc * 3 + 1)
end

def nr_core_arg2(pc)
  nr_proof_read_field(pc * 3 + 2)
end

def nr_core_closure_mask(pc)
  nr_proof_read_meta($nr_proof_closure_masks, pc)
end

def nr_core_closure_match(pc)
  nr_proof_read_meta($nr_proof_closure_matches, pc)
end

def nr_poc_run(code_csv, input, start_pos)
  nr_proof_decode_code(code_csv)
  matched = nr_core_match(input, input.bytesize, start_pos)
  if matched
    puts "status,1"
  else
    puts "status,0"
  end
  matched
end

if ARGV.length < 2
  $stderr.puts "usage: ruby bin/proof_vm_argv.rb OPCODE_CSV INPUT [START_POS]"
  exit 1
end

nr_start_pos = 0
if ARGV.length > 2
  nr_start_pos = ARGV[2].to_i
end

nr_poc_run(ARGV[0], ARGV[1], nr_start_pos)
