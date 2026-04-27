#include <ruby.h>
#include <stdint.h>

#include "generated/regexpinel_spinel_core.c"

typedef struct {
    int32_t *code;
    int64_t *closure_masks;
    int64_t *closure_matches;
    size_t code_len;
    size_t insn_count;
} nr_native_pattern_t;

typedef struct {
    bool matched;
    size_t start_pos;
    size_t end_pos;
    size_t capture_count;
} nr_native_match_range_t;

static VALUE cSpinelPattern;

static size_t
nr_native_utf8_advance(VALUE rb_input, size_t pos)
{
    const uint8_t *input = (const uint8_t *)RSTRING_PTR(rb_input);
    size_t input_len = (size_t)RSTRING_LEN(rb_input);
    uint8_t b0;

    if (pos >= input_len) {
        return pos;
    }

    b0 = input[pos];
    if (b0 < 0x80) {
        return pos + 1;
    }
    if (b0 < 0xe0) {
        return pos + 2;
    }
    if (b0 < 0xf0) {
        return pos + 3;
    }
    return pos + 4;
}

static int
nr_native_noop_on_match(void *data, size_t start_pos, size_t end_pos, size_t capture_count)
{
    (void)data;
    (void)start_pos;
    (void)end_pos;
    (void)capture_count;
    return 0;
}

static int
nr_native_record_on_match(void *data, size_t start_pos, size_t end_pos, size_t capture_count)
{
    nr_native_match_range_t *range = (nr_native_match_range_t *)data;

    range->matched = true;
    range->start_pos = start_pos;
    range->end_pos = end_pos;
    range->capture_count = capture_count;
    return 0;
}

static void
nr_native_pattern_free(void *ptr)
{
    nr_native_pattern_t *pattern = (nr_native_pattern_t *)ptr;

    if (!pattern) {
        return;
    }

    xfree(pattern->code);
    xfree(pattern->closure_masks);
    xfree(pattern->closure_matches);
    xfree(pattern);
}

static size_t
nr_native_pattern_size(const void *ptr)
{
    const nr_native_pattern_t *pattern = (const nr_native_pattern_t *)ptr;

    if (!pattern) {
        return 0;
    }
    return sizeof(*pattern) +
        pattern->code_len * sizeof(*pattern->code) +
        pattern->insn_count * sizeof(*pattern->closure_masks) +
        pattern->insn_count * sizeof(*pattern->closure_matches);
}

static const rb_data_type_t nr_native_pattern_type = {
    "Regexpinel::Spinel::Pattern",
    {
        0,
        nr_native_pattern_free,
        nr_native_pattern_size,
    },
    0,
    0,
    RUBY_TYPED_FREE_IMMEDIATELY
};

static int32_t *
nr_native_code_array(VALUE rb_code, size_t *code_len)
{
    int32_t *code;
    long len = RARRAY_LEN(rb_code);
    long i;

    code = ALLOC_N(int32_t, len);
    for (i = 0; i < len; ++i) {
        VALUE item = rb_ary_entry(rb_code, i);
        code[i] = (int32_t)NUM2INT(item);
    }

    *code_len = (size_t)len;
    return code;
}

static int64_t *
nr_native_i64_array(VALUE rb_array, size_t expected_len)
{
    int64_t *values;
    long len;
    long i;

    Check_Type(rb_array, T_ARRAY);
    len = RARRAY_LEN(rb_array);
    if ((size_t)len != expected_len) {
        rb_raise(rb_eArgError, "metadata array length must match instruction count");
    }

    values = ALLOC_N(int64_t, len);
    for (i = 0; i < len; ++i) {
        VALUE item = rb_ary_entry(rb_array, i);
        values[i] = (int64_t)NUM2LL(item);
    }

    return values;
}

static VALUE
nr_native_pattern_alloc(VALUE klass)
{
    nr_native_pattern_t *pattern;

    pattern = ALLOC(nr_native_pattern_t);
    memset(pattern, 0, sizeof(*pattern));

    return TypedData_Wrap_Struct(klass, &nr_native_pattern_type, pattern);
}

static VALUE
nr_native_pattern_initialize(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_code;
    VALUE rb_closure_masks;
    VALUE rb_closure_matches;
    nr_native_pattern_t *pattern;
    long code_len;

    rb_scan_args(argc, argv, "30", &rb_code, &rb_closure_masks, &rb_closure_matches);
    Check_Type(rb_code, T_ARRAY);
    code_len = RARRAY_LEN(rb_code);
    if (code_len % 3 != 0) {
        rb_raise(rb_eArgError, "instruction array length must be a multiple of 3");
    }
    TypedData_Get_Struct(self, nr_native_pattern_t, &nr_native_pattern_type, pattern);
    xfree(pattern->code);
    xfree(pattern->closure_masks);
    xfree(pattern->closure_matches);
    pattern->code = nr_native_code_array(rb_code, &pattern->code_len);
    pattern->insn_count = pattern->code_len / 3;
    pattern->closure_masks = nr_native_i64_array(rb_closure_masks, pattern->insn_count);
    pattern->closure_matches = nr_native_i64_array(rb_closure_matches, pattern->insn_count);

    return self;
}

static bool
nr_native_pattern_match_range(nr_native_pattern_t *pattern, VALUE rb_input, size_t start_pos, nr_native_match_range_t *range)
{
    memset(range, 0, sizeof(*range));
    return nr_match_core(
        pattern->code,
        pattern->closure_masks,
        pattern->closure_matches,
        pattern->insn_count,
        (const uint8_t *)RSTRING_PTR(rb_input),
        (size_t)RSTRING_LEN(rb_input),
        start_pos,
        nr_native_record_on_match,
        range
    );
}

static bool
nr_native_pattern_find_range(nr_native_pattern_t *pattern, VALUE rb_input, size_t start_pos, nr_native_match_range_t *range)
{
    size_t input_len = (size_t)RSTRING_LEN(rb_input);
    size_t pos = start_pos;

    while (pos <= input_len) {
        if (nr_native_pattern_match_range(pattern, rb_input, pos, range)) {
            return true;
        }
        if (pos >= input_len) {
            break;
        }
        pos = nr_native_utf8_advance(rb_input, pos);
    }

    return false;
}

static VALUE
nr_native_replace_range(VALUE rb_input, VALUE rb_replacement, size_t start_pos, size_t end_pos)
{
    VALUE result = rb_str_subseq(rb_input, 0, 0);
    const char *input = RSTRING_PTR(rb_input);
    size_t input_len = (size_t)RSTRING_LEN(rb_input);

    rb_str_cat(result, input, start_pos);
    rb_str_append(result, rb_replacement);
    rb_str_cat(result, input + end_pos, input_len - end_pos);
    return result;
}

static VALUE
nr_native_pattern_match_p(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_input;
    VALUE rb_start_pos;
    nr_native_pattern_t *pattern;
    size_t start_pos = 0;
    bool matched;

    rb_scan_args(argc, argv, "11", &rb_input, &rb_start_pos);
    StringValue(rb_input);
    if (!NIL_P(rb_start_pos)) {
        start_pos = (size_t)NUM2SIZET(rb_start_pos);
    }

    TypedData_Get_Struct(self, nr_native_pattern_t, &nr_native_pattern_type, pattern);
    matched = nr_match_core(
        pattern->code,
        pattern->closure_masks,
        pattern->closure_matches,
        pattern->insn_count,
        (const uint8_t *)RSTRING_PTR(rb_input),
        (size_t)RSTRING_LEN(rb_input),
        start_pos,
        nr_native_noop_on_match,
        NULL
    );

    return matched ? Qtrue : Qfalse;
}

static VALUE
nr_native_pattern_sub(VALUE self, VALUE rb_input, VALUE rb_replacement)
{
    nr_native_pattern_t *pattern;
    nr_native_match_range_t range;

    StringValue(rb_input);
    StringValue(rb_replacement);
    TypedData_Get_Struct(self, nr_native_pattern_t, &nr_native_pattern_type, pattern);

    if (!nr_native_pattern_find_range(pattern, rb_input, 0, &range)) {
        return rb_str_dup(rb_input);
    }

    return nr_native_replace_range(rb_input, rb_replacement, range.start_pos, range.end_pos);
}

static VALUE
nr_native_pattern_gsub(VALUE self, VALUE rb_input, VALUE rb_replacement)
{
    nr_native_pattern_t *pattern;
    nr_native_match_range_t range;
    VALUE result;
    size_t input_len;
    size_t search_pos = 0;
    size_t copy_pos = 0;

    StringValue(rb_input);
    StringValue(rb_replacement);
    TypedData_Get_Struct(self, nr_native_pattern_t, &nr_native_pattern_type, pattern);

    input_len = (size_t)RSTRING_LEN(rb_input);
    result = rb_str_subseq(rb_input, 0, 0);

    while (search_pos <= input_len) {
        if (!nr_native_pattern_find_range(pattern, rb_input, search_pos, &range)) {
            break;
        }

        rb_str_cat(result, RSTRING_PTR(rb_input) + copy_pos, range.start_pos - copy_pos);
        rb_str_append(result, rb_replacement);

        if (range.end_pos == range.start_pos) {
            if (range.end_pos >= input_len) {
                copy_pos = range.end_pos;
                break;
            }
            search_pos = nr_native_utf8_advance(rb_input, range.end_pos);
            rb_str_cat(result, RSTRING_PTR(rb_input) + range.end_pos, search_pos - range.end_pos);
            copy_pos = search_pos;
        } else {
            search_pos = range.end_pos;
            copy_pos = range.end_pos;
        }
    }

    rb_str_cat(result, RSTRING_PTR(rb_input) + copy_pos, input_len - copy_pos);
    return result;
}

static VALUE
nr_native_match_code_p(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_code;
    VALUE rb_closure_masks;
    VALUE rb_closure_matches;
    VALUE rb_input;
    VALUE rb_start_pos;
    int32_t *code;
    int64_t *closure_masks;
    int64_t *closure_matches;
    size_t code_len;
    size_t start_pos = 0;
    bool matched;

    (void)self;
    rb_scan_args(argc, argv, "41", &rb_code, &rb_closure_masks, &rb_closure_matches, &rb_input, &rb_start_pos);
    Check_Type(rb_code, T_ARRAY);
    StringValue(rb_input);
    if (!NIL_P(rb_start_pos)) {
        start_pos = (size_t)NUM2SIZET(rb_start_pos);
    }

    code_len = (size_t)RARRAY_LEN(rb_code);
    if (code_len % 3 != 0) {
        rb_raise(rb_eArgError, "instruction array length must be a multiple of 3");
    }

    code = nr_native_code_array(rb_code, &code_len);
    closure_masks = nr_native_i64_array(rb_closure_masks, code_len / 3);
    closure_matches = nr_native_i64_array(rb_closure_matches, code_len / 3);
    matched = nr_match_core(
        code,
        closure_masks,
        closure_matches,
        code_len / 3,
        (const uint8_t *)RSTRING_PTR(rb_input),
        (size_t)RSTRING_LEN(rb_input),
        start_pos,
        nr_native_noop_on_match,
        NULL
    );
    xfree(closure_masks);
    xfree(closure_matches);
    xfree(code);

    return matched ? Qtrue : Qfalse;
}

void
Init_regexpinel_spinel(void)
{
    VALUE mRegexpinel = rb_define_module("Regexpinel");
    VALUE mSpinel = rb_define_module_under(mRegexpinel, "Spinel");

    rb_define_singleton_method(mSpinel, "match_code?", nr_native_match_code_p, -1);

    cSpinelPattern = rb_define_class_under(mSpinel, "Pattern", rb_cObject);
    rb_define_alloc_func(cSpinelPattern, nr_native_pattern_alloc);
    rb_define_method(cSpinelPattern, "initialize", nr_native_pattern_initialize, -1);
    rb_define_method(cSpinelPattern, "match?", nr_native_pattern_match_p, -1);
    rb_define_method(cSpinelPattern, "sub", nr_native_pattern_sub, 2);
    rb_define_method(cSpinelPattern, "gsub", nr_native_pattern_gsub, 2);
}
