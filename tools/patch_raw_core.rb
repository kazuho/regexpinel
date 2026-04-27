#!/usr/bin/env ruby

input_path = ARGV[0]
output_path = ARGV[1]

unless input_path && output_path
  abort "usage: #{$PROGRAM_NAME} INPUT_GENERATED_C OUTPUT_RAW_CORE_C"
end

source = File.read(input_path)

def replace_exact!(source, from, to, label)
  count = source.scan(from).length
  unless count == 1
    abort "expected exactly one #{label}, found #{count}"
  end
  source.sub!(from, to)
end

def replace_function!(source, signature_pattern, replacement, label)
  pattern = /#{signature_pattern} \{.*?^}/m
  count = source.scan(pattern).length
  unless count == 1
    abort "expected exactly one #{label}, found #{count}"
  end
  source.sub!(pattern, replacement)
end

def remove_block!(source, start_pattern, end_pattern, label)
  pattern = /#{start_pattern}.*?(?=#{end_pattern})/m
  count = source.scan(pattern).length
  unless count == 1
    abort "expected exactly one #{label}, found #{count}"
  end
  source.sub!(pattern, "")
end

# Boundary 1: the generated core should not depend on Spinel's runtime headers.
replace_exact!(
  source,
  '#include "sp_runtime.h"',
  <<~C.chomp,
    #include <stdbool.h>
    #include <stddef.h>
    #include <stdint.h>

    typedef int64_t mrb_int;
    typedef bool mrb_bool;
    typedef mrb_int sp_sym;
    #ifndef TRUE
    #define TRUE true
    #endif
    #ifndef FALSE
    #define FALSE false
    #endif

    typedef int (*nr_on_match_callback)(void *data, size_t start_pos, size_t end_pos, size_t capture_count);

    static const int32_t *nr_raw_code = NULL;
    static size_t nr_raw_insn_count = 0;
    static nr_on_match_callback nr_raw_on_match = NULL;
    static void *nr_raw_on_match_data = NULL;
  C
  "runtime include"
)

# Boundary 2: bytecode comes from the extension's raw int32_t array, not from the
# proof runner's CSV string buffer.
%w[
  static\ const\ char\ \*\ gv_nr_proof_code\ =\ "";
  static\ mrb_int\ gv_nr_proof_insn_count\ =\ 0;
  static\ inline\ mrb_int\ sp_nr_proof_slot_offset\(mrb_int\ lv_field_index\);
  static\ mrb_int\ sp_nr_proof_write_field\(mrb_int\ lv_field_index,\ mrb_int\ lv_value\);
  static\ mrb_int\ sp_nr_proof_read_field\(mrb_int\ lv_field_index\);
  static\ mrb_int\ sp_nr_proof_decode_code\(const\ char\ \*\ lv_code_csv\);
  static\ mrb_int\ cst_NR_PROOF_MAX_INSNS\ =\ 0;
  static\ mrb_int\ cst_NR_PROOF_SLOT_SIZE\ =\ 0;
  static\ mrb_int\ cst_NR_PROOF_BUFFER_SIZE\ =\ 0;
].each do |pattern|
  replace_exact!(source, Regexp.new(pattern), "", pattern)
end

remove_block!(
  source,
  /static inline mrb_int sp_nr_proof_slot_offset\(mrb_int lv_field_index\) \{/,
  /static inline mrb_int sp_nr_core_op\(mrb_int lv_pc\) \{/,
  "proof bytecode decoder block"
)

replace_function!(
  source,
  /static inline mrb_int sp_nr_core_insn_count\(void\)/,
  <<~C.chomp,
    static inline mrb_int sp_nr_core_insn_count(void) {
        return (mrb_int)nr_raw_insn_count;
      return 0;
    }
  C
  "instruction count accessor"
)

replace_function!(
  source,
  /static inline mrb_int sp_nr_core_op\(mrb_int lv_pc\)/,
  <<~C.chomp,
    static inline mrb_int sp_nr_core_op(mrb_int lv_pc) {
        return (mrb_int)nr_raw_code[lv_pc * 3];
      return 0;
    }
  C
  "opcode accessor"
)

replace_function!(
  source,
  /static inline mrb_int sp_nr_core_arg1\(mrb_int lv_pc\)/,
  <<~C.chomp,
    static inline mrb_int sp_nr_core_arg1(mrb_int lv_pc) {
        return (mrb_int)nr_raw_code[lv_pc * 3 + 1];
      return 0;
    }
  C
  "arg1 accessor"
)

replace_function!(
  source,
  /static inline mrb_int sp_nr_core_arg2\(mrb_int lv_pc\)/,
  <<~C.chomp,
    static inline mrb_int sp_nr_core_arg2(mrb_int lv_pc) {
        return (mrb_int)nr_raw_code[lv_pc * 3 + 2];
      return 0;
    }
  C
  "arg2 accessor"
)

# Boundary 3: matches are reported through the extension callback.
replace_function!(
  source,
  /static mrb_int sp_nr_on_match\(mrb_int lv_start_pos, mrb_int lv_end_pos, mrb_int lv_capture_count\)/,
  <<~C.chomp,
    static mrb_int sp_nr_on_match(mrb_int lv_start_pos, mrb_int lv_end_pos, mrb_int lv_capture_count) {
        if (!nr_raw_on_match) {
          return 0;
        }
        return (mrb_int)nr_raw_on_match(
          nr_raw_on_match_data,
          (size_t)lv_start_pos,
          (size_t)lv_end_pos,
          (size_t)lv_capture_count
        );
      return 0;
    }
  C
  "match callback"
)

# Boundary 4: remove the proof executable entrypoint and expose the raw matcher
# ABI consumed by the CRuby extension.
replace_exact!(
  source,
  'static mrb_bool sp_nr_poc_run(const char * lv_code_csv, const char * lv_input, mrb_int lv_start_pos);',
  '',
  "proof runner declaration"
)
source.sub!(/static mrb_bool sp_nr_poc_run\(.*\z/m, "")

entrypoint = <<~C

  bool nr_match_core(
      const int32_t *code,
      size_t insn_count,
      const uint8_t *input,
      size_t input_len,
      size_t start_pos,
      nr_on_match_callback on_match,
      void *on_match_data)
  {
      nr_raw_code = code;
      nr_raw_insn_count = insn_count;
      nr_raw_on_match = on_match;
      nr_raw_on_match_data = on_match_data;

      return sp_nr_core_match((const char *)input, (mrb_int)input_len, (mrb_int)start_pos);
  }
C

source = "#{source.rstrip}\n#{entrypoint}"

forbidden = %w[
  sp_IntArray
  sp_gc_alloc
  sp_gc_alloc_nogc
  sp_str_alloc
  malloc
  calloc
  realloc
  free
  mmap
  fputs
  printf
  puts
  putchar
  strlen
  sp_nr_poc_run
  main(
]

violations = forbidden.select { |token| source.include?(token) }
unless violations.empty?
  abort "patched raw core contains forbidden tokens: #{violations.join(", ")}"
end

File.write(output_path, source)
