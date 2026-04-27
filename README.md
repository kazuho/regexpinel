# regexpinel

Standalone workspace for a Spinel-compilable regexp engine.

Spinel is intentionally kept outside this repository. Commands that generate or
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
- `lib/regexpinel/spinel.rb`: Ruby loader for `Regexpinel::Spinel`
- `Regexpinel::CRuby.new(pattern)` compiles the same bytecode and runs the Ruby
  executor directly inside CRuby
- `Regexpinel::Spinel.new(pattern)` builds a Ruby-facing Spinel-backed regexp object
  with `match?(string, start_pos = 0)`
- `Regexpinel::Spinel.match_code?(code, string, start_pos = 0)` calls the native
  executor; Ruby argument conversion, bytecode storage, and result construction
  happen outside the executor core
- `tools/patch_raw_core.rb`: deterministic post-processor for Spinel-emitted C;
  it removes the generated argv/stdio/runtime surface and emits a raw-buffer
  matcher entrypoint
- `tools/proof_vm_argv_raw.c`: proof executable wrapper that decodes argv into a
  fixed instruction buffer and supplies `puts`/`printf`-style callbacks outside
  the allocation-free matcher core

From the regexpinel repository root, build the extension:

```sh
SPINEL=/path/to/spinel ruby extconf.rb
make
```
