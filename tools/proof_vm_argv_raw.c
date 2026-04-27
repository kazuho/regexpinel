#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "regexpinel_raw_core.c"

#define NR_PROOF_MAX_FIELDS (64 * 3)

static int32_t nr_proof_code[NR_PROOF_MAX_FIELDS];

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

    matched = nr_match_core(
        nr_proof_code,
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
