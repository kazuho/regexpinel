# regexpinel

Proof-of-concept implementation of Ruby's `Regexp` in Ruby. The regexp engine is
implemented as a small Ruby VM. Spinel is used to compile that Ruby VM
implementation into an allocation-free C library.

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
  with `match?(string, start_pos = 0)`
- `Regexpinel::Spinel.match_code?(code, string, start_pos = 0)` calls the native
  executor; Ruby argument conversion, bytecode storage, and result construction
  happen outside the executor core
- `tools/patch_raw_core.rb`: deterministic post-processor for Spinel-emitted C;
  it removes the argv/stdio boundary and emits the raw-buffer `nr_match_core(...)`
  ABI used by the extension
- `tools/proof_vm_argv_raw.c`: proof executable wrapper that decodes argv into a
  fixed instruction buffer and supplies `puts`/`printf`-style callbacks outside
  the allocation-free matcher core

From the regexpinel repository root, build the extension:

```sh
SPINEL=/path/to/spinel ruby extconf.rb
make
```

Benchmark:

```sh
SPINEL=/path/to/spinel ruby benchmark/bench_synthetic.rb
```

The synthetic benchmark compares three implementations over the same supported
pattern subset and writes the raw result data to `benchmark/results/synthetic.json`.
An example run on this machine produced:

| Implementation | What It Runs | Avg Checks/Sec | Vs CRuby |
| --- | --- | ---: | ---: |
| CRuby `Regexp` | CRuby's built-in regexp engine | 18,634,846 | 1.00x |
| `Regexpinel::Spinel` | Patched Spinel-generated C for the Ruby VM core, called from a CRuby extension | 30,425,565 | 1.63x |
| `Regexpinel::CRuby` | Same bytecode executed by the Ruby VM | 933,798 | 0.05x |
