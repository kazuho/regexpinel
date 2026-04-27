#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int nr_alloc_counting_enabled = 0;
static unsigned long nr_malloc_calls = 0;
static unsigned long nr_calloc_calls = 0;
static unsigned long nr_realloc_calls = 0;

static void *nr_real_malloc(size_t size) { return malloc(size); }
static void *nr_real_calloc(size_t count, size_t size) { return calloc(count, size); }
static void *nr_real_realloc(void *ptr, size_t size) { return realloc(ptr, size); }
static void nr_real_free(void *ptr) { free(ptr); }

static void *nr_counted_malloc(size_t size)
{
    if (nr_alloc_counting_enabled) {
        nr_malloc_calls++;
    }
    return nr_real_malloc(size);
}

static void *nr_counted_calloc(size_t count, size_t size)
{
    if (nr_alloc_counting_enabled) {
        nr_calloc_calls++;
    }
    return nr_real_calloc(count, size);
}

static void *nr_counted_realloc(void *ptr, size_t size)
{
    if (nr_alloc_counting_enabled) {
        nr_realloc_calls++;
    }
    return nr_real_realloc(ptr, size);
}

static void nr_counted_free(void *ptr)
{
    nr_real_free(ptr);
}

#define malloc nr_counted_malloc
#define calloc nr_counted_calloc
#define realloc nr_counted_realloc
#define free nr_counted_free

#include NR_GENERATED_C_PATH

#undef malloc
#undef calloc
#undef realloc
#undef free

static const int32_t nr_code[] = {
    1, 97, 3,
    1, 98, 4,
    1, 99, 4,
    4, 1, 2,
    1, 100, 5,
    5, 0, 0
};

static const int64_t nr_closure_masks[] = {
    6, 16, 16, 0, 0, 0
};

static const int64_t nr_closure_matches[] = {
    0, 0, 0, 0, 1, 0
};

static int
nr_harness_on_match(void *data, size_t start_pos, size_t end_pos, size_t capture_count)
{
    (void)data;
    printf("match,%zu,%zu,%zu\n", start_pos, end_pos, capture_count);
    return 0;
}

static int nr_run_once(const char *input, size_t start_pos)
{
    return nr_match_core(
        nr_code,
        nr_closure_masks,
        nr_closure_matches,
        sizeof(nr_code) / sizeof(nr_code[0]) / 3,
        (const uint8_t *)input,
        strlen(input),
        start_pos,
        nr_harness_on_match,
        NULL
    ) ? 1 : 0;
}

int main(void)
{
    int matched1;
    int matched2;
    int matched3;
    unsigned long total_allocs;

    nr_malloc_calls = 0;
    nr_calloc_calls = 0;
    nr_realloc_calls = 0;
    nr_alloc_counting_enabled = 1;

    matched1 = nr_run_once("acd", 0);
    matched2 = nr_run_once("aed", 0);
    matched3 = nr_run_once("zacd", 1);

    nr_alloc_counting_enabled = 0;
    total_allocs = nr_malloc_calls + nr_calloc_calls + nr_realloc_calls;

    printf("matched1,%d\n", matched1);
    printf("matched2,%d\n", matched2);
    printf("matched3,%d\n", matched3);
    printf("malloc_calls,%lu\n", nr_malloc_calls);
    printf("calloc_calls,%lu\n", nr_calloc_calls);
    printf("realloc_calls,%lu\n", nr_realloc_calls);
    printf("total_alloc_calls,%lu\n", total_allocs);

    if (matched1 != 1 || matched2 != 0 || matched3 != 1 || total_allocs != 0) {
        return 1;
    }
    return 0;
}
