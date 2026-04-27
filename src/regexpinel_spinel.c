#include <ruby.h>
#include <stdint.h>

#include "generated/regexpinel_spinel_core.c"

typedef struct {
    int32_t *code;
    size_t code_len;
    size_t insn_count;
} nr_native_pattern_t;

static VALUE cSpinelPattern;

static int
nr_native_noop_on_match(void *data, size_t start_pos, size_t end_pos, size_t capture_count)
{
    (void)data;
    (void)start_pos;
    (void)end_pos;
    (void)capture_count;
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
    xfree(pattern);
}

static size_t
nr_native_pattern_size(const void *ptr)
{
    const nr_native_pattern_t *pattern = (const nr_native_pattern_t *)ptr;

    if (!pattern) {
        return 0;
    }
    return sizeof(*pattern) + pattern->code_len * sizeof(*pattern->code);
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

static VALUE
nr_native_pattern_alloc(VALUE klass)
{
    nr_native_pattern_t *pattern;

    pattern = ALLOC(nr_native_pattern_t);
    memset(pattern, 0, sizeof(*pattern));

    return TypedData_Wrap_Struct(klass, &nr_native_pattern_type, pattern);
}

static VALUE
nr_native_pattern_initialize(VALUE self, VALUE rb_code)
{
    nr_native_pattern_t *pattern;
    long code_len;

    Check_Type(rb_code, T_ARRAY);
    code_len = RARRAY_LEN(rb_code);
    if (code_len % 3 != 0) {
        rb_raise(rb_eArgError, "instruction array length must be a multiple of 3");
    }

    TypedData_Get_Struct(self, nr_native_pattern_t, &nr_native_pattern_type, pattern);
    xfree(pattern->code);
    pattern->code = nr_native_code_array(rb_code, &pattern->code_len);
    pattern->insn_count = pattern->code_len / 3;

    return self;
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
nr_native_match_code_p(int argc, VALUE *argv, VALUE self)
{
    VALUE rb_code;
    VALUE rb_input;
    VALUE rb_start_pos;
    int32_t *code;
    size_t code_len;
    size_t start_pos = 0;
    bool matched;

    (void)self;
    rb_scan_args(argc, argv, "21", &rb_code, &rb_input, &rb_start_pos);
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
    matched = nr_match_core(
        code,
        code_len / 3,
        (const uint8_t *)RSTRING_PTR(rb_input),
        (size_t)RSTRING_LEN(rb_input),
        start_pos,
        nr_native_noop_on_match,
        NULL
    );
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
    rb_define_method(cSpinelPattern, "initialize", nr_native_pattern_initialize, 1);
    rb_define_method(cSpinelPattern, "match?", nr_native_pattern_match_p, -1);
}
