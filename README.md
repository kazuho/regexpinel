# regexpinel

Proof-of-concept `Regexp` implentation as alternative to that in CRuby. The
regexp engine is implemented as a small Ruby VM. Spinel is used to compile that
Ruby VM implementation into an allocation-free C library, which in turn is
wrapped as a CRuby extension.

This is not a complete regexp engine. The current scope is deliberately small
and exists to validate the execution model, native boundary, and allocation
proofs before expanding feature coverage.

Spinel is intentionally kept outside this repository. Commands that regenerate or
verify Spinel-backed code require `SPINEL` to point to the external compiler:

```sh
export SPINEL=/path/to/spinel
```

Initial scope:

- Thompson-style VM executor
- boolean `match?`
- UTF-8 codepoint `sub` / `gsub` replacement
- flat integer instruction encoding
- reusable execution context
- no allocation inside the executor

Directory layout:

- `VM.md`: VM format and execution contract
- `lib/`: executor/context code
- `test/`: focused validation scripts

Spinel-backed extension:

- `src/`: CRuby extension wrapper around Spinel-generated
  executor code patched to expose the raw `nr_match_core(...)` C ABI
- `bin/proof_vm_argv.rb`: Ruby file passed to Spinel; it requires the shared VM
  core from `lib/regexpinel/core.rb`
- `lib/regexpinel/spinel.rb`: Ruby loader for `Regexpinel::Spinel`
- `Regexpinel::CRuby.new(pattern)` compiles the same bytecode and runs the Ruby
  executor directly inside CRuby
- `Regexpinel::Spinel.new(pattern)` builds a Ruby-facing Spinel-backed regexp object
  with `match?(string, start_pos = 0)`, `sub(string, replacement)`, and
  `gsub(string, replacement)`
- `Regexpinel::Spinel.match_code?(code, string, start_pos = 0)` calls the native
  executor; Ruby argument conversion, bytecode storage, and result construction
  happen outside the executor core
- `tools/patch_raw_core.rb`: deterministic post-processor for Spinel-emitted C;
  it removes the argv/stdio boundary and emits the raw-buffer `nr_match_core(...)`
  ABI used by the extension
- `tools/proof_vm_argv_raw.c`: proof executable wrapper that decodes argv into a
  fixed instruction buffer and supplies `puts`/`printf`-style callbacks outside
  the allocation-free matcher core

Substitution support is deliberately narrow. The matcher assumes valid UTF-8,
iterates by codepoint, reports accepted byte ranges through the VM callback, and
performs literal string replacement outside the executor by splicing those byte
ranges.
Capture expansion, backreferences, and CRuby-compatible greedy quantifier ranges
are not implemented yet.

From the regexpinel repository root, build the extension:

```sh
SPINEL=/path/to/spinel ruby extconf.rb
make
```

Benchmark:

```sh
SPINEL=/path/to/spinel ruby benchmark/bench_synthetic.rb
SPINEL=/path/to/spinel ruby benchmark/bench_substitution.rb
SPINEL=/path/to/spinel ruby benchmark/bench_long_inputs.rb
```

The synthetic benchmark compares three implementations over the same supported
pattern subset and writes the raw result data to `benchmark/results/synthetic.json`.
An example run on this machine produced:

| Implementation | What It Runs | Avg Checks/Sec | Vs CRuby |
| --- | --- | ---: | ---: |
| CRuby `Regexp` | CRuby's built-in regexp engine | 19,037,261 | 1.00x |
| `Regexpinel::Spinel` | Patched Spinel-generated C for the Ruby VM core, called from a CRuby extension | 31,925,547 | 1.68x |
| `Regexpinel::CRuby` | Same bytecode executed by the Ruby VM | 902,166 | 0.05x |

The substitution benchmark compares literal replacement for supported subset cases
where regexpinel and CRuby produce the same output. It writes raw result data to
`benchmark/results/substitution.json`. An example run on this machine with
`loops=200` produced:

| Operation | Implementation | Avg Ops/Sec | Vs CRuby |
| --- | --- | ---: | ---: |
| `sub` | CRuby `Regexp` | 5,180,703 | 1.00x |
| `sub` | `Regexpinel::Spinel` | 12,814,179 | 2.47x |
| `sub` | `Regexpinel::CRuby` | 389,489 | 0.08x |
| `gsub` | CRuby `Regexp` | 3,169,890 | 1.00x |
| `gsub` | `Regexpinel::Spinel` | 10,993,974 | 3.47x |
| `gsub` | `Regexpinel::CRuby` | 295,045 | 0.09x |

The long-input benchmark uses anchored matches over roughly 1 KiB inputs and
reports throughput in MiB/sec to reduce the influence of per-call overhead. It
writes raw result data to `benchmark/results/long_inputs.json`. An example run
on this machine with `loops=50` produced:

| Case | Pattern | CRuby MiB/Sec | `Regexpinel::Spinel` MiB/Sec | `Regexpinel::CRuby` MiB/Sec |
| --- | --- | ---: | ---: | ---: |
| long star literal match | `z*ab` | 362.2 | 349.3 | 1.0 |
| long star literal miss | `z*ab` | 3,918.6 | 345.1 | 1.0 |
| long plus match | `a+b` | 417.0 | 439.6 | 1.1 |
| long plus miss | `a+b` | 413.7 | 415.3 | 1.1 |
| long UTF-8 match | `é*x` | 387.8 | 668.6 | 2.1 |
