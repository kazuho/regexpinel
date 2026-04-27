#!/usr/bin/env ruby

require_relative "../lib/regexpinel/core"

NR_PROOF_MAX_INSNS = 64
NR_PROOF_SLOT_SIZE = 12
NR_PROOF_BUFFER_SIZE = NR_PROOF_MAX_INSNS * NR_PROOF_SLOT_SIZE

$nr_proof_code = "\1" * NR_PROOF_BUFFER_SIZE
$nr_proof_insn_count = 0

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
