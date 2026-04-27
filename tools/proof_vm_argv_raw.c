#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "regexpinel_raw_core.c"

#define NR_PROOF_MAX_FIELDS (64 * 3)

static int32_t nr_proof_code[NR_PROOF_MAX_FIELDS];
static int64_t nr_proof_closure_masks[64];
static int64_t nr_proof_closure_matches[64];

static size_t
nr_decode_code_csv(const char *csv)
{
    size_t pos = 0;
    size_t field_index = 0;
    int32_t value = 0;
    int have_digit = 0;

    while (csv[pos] != 0) {
        unsigned char byte = (unsigned char)csv[pos];
        if (byte >= '0' && byte <= '9') {
            value = value * 10 + (int32_t)(byte - '0');
            have_digit = 1;
        } else if (byte == ',') {
            if (field_index >= NR_PROOF_MAX_FIELDS) {
                return 0;
            }
            nr_proof_code[field_index++] = value;
            value = 0;
            have_digit = 0;
        }
        ++pos;
    }

    if (have_digit != 0) {
        if (field_index >= NR_PROOF_MAX_FIELDS) {
            return 0;
        }
        nr_proof_code[field_index++] = value;
    }

    if (field_index % 3 != 0) {
        return 0;
    }
    return field_index / 3;
}

static int64_t
nr_compute_closure(size_t insn_count, int start_pc, int64_t *matched)
{
    int stack0 = start_pc;
    int stack1 = 0;
    int stack_top = 1;
    int64_t visited = 0;
    int64_t state_mask = 0;

    *matched = 0;
    while (stack_top > 0) {
        int cur;
        int64_t bit;
        int op;

        stack_top--;
        cur = stack_top == 0 ? stack0 : stack1;
        bit = ((int64_t)1) << cur;
        if ((visited & bit) != 0) {
            continue;
        }
        visited |= bit;

        op = nr_proof_code[cur * 3];
        if (op == 3) {
            if (stack_top == 0) {
                stack0 = nr_proof_code[cur * 3 + 1];
            } else {
                stack1 = nr_proof_code[cur * 3 + 1];
            }
            stack_top++;
        } else if (op == 4) {
            if (stack_top == 0) {
                stack0 = nr_proof_code[cur * 3 + 1];
            } else {
                stack1 = nr_proof_code[cur * 3 + 1];
            }
            stack_top++;

            if (stack_top == 0) {
                stack0 = nr_proof_code[cur * 3 + 2];
            } else {
                stack1 = nr_proof_code[cur * 3 + 2];
            }
            stack_top++;
        } else if (op == 5) {
            *matched = 1;
        } else {
            state_mask |= bit;
        }
    }

    (void)insn_count;
    return state_mask;
}

static void
nr_compile_closures(size_t insn_count)
{
    size_t pc;

    memset(nr_proof_closure_masks, 0, sizeof(nr_proof_closure_masks));
    memset(nr_proof_closure_matches, 0, sizeof(nr_proof_closure_matches));
    for (pc = 0; pc < insn_count; ++pc) {
        int op = nr_proof_code[pc * 3];
        int64_t matched = 0;

        if (op == 1) {
            nr_proof_closure_masks[pc] = nr_compute_closure(insn_count, nr_proof_code[pc * 3 + 2], &matched);
            nr_proof_closure_matches[pc] = matched;
        } else if (op == 2) {
            nr_proof_closure_masks[pc] = nr_compute_closure(insn_count, nr_proof_code[pc * 3 + 1], &matched);
            nr_proof_closure_matches[pc] = matched;
        }
    }
}

static int
nr_proof_on_match(void *data, size_t start_pos, size_t end_pos, size_t capture_count)
{
    (void)data;
    printf("match,%zu,%zu,%zu\n", start_pos, end_pos, capture_count);
    return 0;
}

int
main(int argc, char **argv)
{
    size_t insn_count;
    size_t start_pos = 0;
    bool matched;

    if (argc < 3) {
        fputs("usage: proof_vm_argv_raw OPCODE_CSV INPUT [START_POS]\n", stderr);
        return 1;
    }

    if (argc > 3) {
        start_pos = (size_t)strtoull(argv[3], NULL, 10);
    }

    insn_count = nr_decode_code_csv(argv[1]);
    if (insn_count == 0) {
        fputs("invalid instruction csv\n", stderr);
        return 1;
    }
    nr_compile_closures(insn_count);

    matched = nr_match_core(
        nr_proof_code,
        nr_proof_closure_masks,
        nr_proof_closure_matches,
        insn_count,
        (const uint8_t *)argv[2],
        strlen(argv[2]),
        start_pos,
        nr_proof_on_match,
        NULL
    );

    puts(matched ? "status,1" : "status,0");
    return matched ? 0 : 2;
}
