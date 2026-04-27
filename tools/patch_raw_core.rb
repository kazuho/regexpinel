#!/usr/bin/env ruby

input_path = ARGV[0]
output_path = ARGV[1]

unless input_path && output_path
  abort "usage: #{$PROGRAM_NAME} INPUT_GENERATED_C OUTPUT_RAW_CORE_C"
end

source = File.read(input_path)

replacements = {
  '#include "sp_runtime.h"' => <<~C.chomp,
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
    static size_t nr_raw_input_len = 0;
    static nr_on_match_callback nr_raw_on_match = NULL;
    static void *nr_raw_on_match_data = NULL;
  C
  'static const char * gv_nr_proof_code = "";' => '',
  'static mrb_int gv_nr_proof_insn_count = 0;' => '',
  'static inline mrb_int sp_nr_proof_slot_offset(mrb_int lv_field_index);' => '',
  'static mrb_int sp_nr_proof_write_field(mrb_int lv_field_index, mrb_int lv_value);' => '',
  'static mrb_int sp_nr_proof_read_field(mrb_int lv_field_index);' => '',
  'static mrb_int sp_nr_proof_decode_code(const char * lv_code_csv);' => '',
  'static mrb_bool sp_nr_poc_run(const char * lv_code_csv, const char * lv_input, mrb_int lv_start_pos);' => '',
  'static mrb_int cst_NR_PROOF_MAX_INSNS = 0;' => '',
  'static mrb_int cst_NR_PROOF_SLOT_SIZE = 0;' => '',
  'static mrb_int cst_NR_PROOF_BUFFER_SIZE = 0;' => '',
  '    mrb_int _t1 = (mrb_int)strlen(lv_input);' => '    mrb_int _t1 = (mrb_int)nr_raw_input_len;'
}

replacements.each do |from, to|
  source = source.gsub(from, to)
end

source = source.sub(
  /static mrb_int sp_nr_on_match\(mrb_int lv_start_pos, mrb_int lv_end_pos, mrb_int lv_capture_count\) \{.*?\n\}/m,
  <<~C.chomp
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
)

source = source.sub(
  /static inline mrb_int sp_nr_core_insn_count\(void\) \{.*?\n\}/m,
  <<~C.chomp
    static inline mrb_int sp_nr_core_insn_count(void) {
        return (mrb_int)nr_raw_insn_count;
      return 0;
    }
  C
)

source = source.sub(
  /static inline mrb_int sp_nr_proof_slot_offset\(mrb_int lv_field_index\).*?static inline mrb_int sp_nr_core_op\(mrb_int lv_pc\) \{/m,
  "static inline mrb_int sp_nr_core_op(mrb_int lv_pc) {"
)

source = source.sub(
  /static inline mrb_int sp_nr_core_op\(mrb_int lv_pc\) \{.*?\n\}/m,
  <<~C.chomp
    static inline mrb_int sp_nr_core_op(mrb_int lv_pc) {
        return (mrb_int)nr_raw_code[lv_pc * 3];
      return 0;
    }
  C
)

source = source.sub(
  /static inline mrb_int sp_nr_core_arg1\(mrb_int lv_pc\) \{.*?\n\}/m,
  <<~C.chomp
    static inline mrb_int sp_nr_core_arg1(mrb_int lv_pc) {
        return (mrb_int)nr_raw_code[lv_pc * 3 + 1];
      return 0;
    }
  C
)

source = source.sub(
  /static inline mrb_int sp_nr_core_arg2\(mrb_int lv_pc\) \{.*?\n\}/m,
  <<~C.chomp
    static inline mrb_int sp_nr_core_arg2(mrb_int lv_pc) {
        return (mrb_int)nr_raw_code[lv_pc * 3 + 2];
      return 0;
    }
  C
)

source = source.sub(/static mrb_bool sp_nr_poc_run\(.*\z/m, "")

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
      nr_raw_input_len = input_len;
      nr_raw_on_match = on_match;
      nr_raw_on_match_data = on_match_data;

      return sp_nr_core_match((const char *)input, (mrb_int)start_pos);
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
