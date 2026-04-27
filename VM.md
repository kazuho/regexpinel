# VM Spec

## Current VM Scope

This document defines the locked contract for the first executable slice of
this repository.

The current bytecode subset supports:

- literal byte match
- wildcard byte match
- jump
- split
- match
- boolean `match?`
- final match notification through a callback

Not supported yet:

- regexp parser/compiler
- capture groups
- backreferences
- anchors
- character classes
- Unicode-aware matching
- replacement APIs

## 0A. Contract Lock

### Executor role

The executor is a pure-Ruby VM matcher that must run on both:

- CRuby
- Spinel-generated native code

The executor is not allowed to:

- print
- allocate result objects
- allocate result arrays
- construct `MatchData`
- perform wrapper / integration work

The executor is allowed to:

- return `true` or `false` as a control-flow convenience
- invoke fixed callbacks owned by the caller

### Callback contract

For the current bytecode subset, the only required callback is:

```ruby
nr_on_match(start_pos, end_pos, capture_count)
```

Arguments:

- `start_pos`: integer input offset where the accepted match began
- `end_pos`: integer input offset just past the accepted match
- `capture_count`: integer count of captures reported by this VM run

For the current bytecode subset:

- `capture_count` is always `0`

Rules:

- callback is invoked only on final successful acceptance
- callback is never invoked for speculative intermediate states
- callback is part of the caller contract, not defined by the executor

### Return value contract

The executor returns:

- `true` on accepted match
- `false` on failure

This return value is only for control flow. Observable reporting still flows
through callbacks.

## 0B. Core VM Shape

## Instruction encoding

Instructions are stored as one flat integer array.

Each instruction occupies exactly 3 integer slots:

```text
[opcode, arg1, arg2]
```

The program counter (`pc`) is an instruction index, not a byte offset.

Instruction decode:

```text
base = pc * 3
opcode = code[base]
arg1 = code[base + 1]
arg2 = code[base + 2]
```

## Opcodes

### `NR_OP_CHAR`

```text
[NR_OP_CHAR, byte_value, next_pc]
```

Consumes one input byte if it equals `byte_value`.

### `NR_OP_ANY`

```text
[NR_OP_ANY, next_pc, 0]
```

Consumes one input byte if available.

### `NR_OP_JMP`

```text
[NR_OP_JMP, target_pc, 0]
```

Epsilon jump.

### `NR_OP_SPLIT`

```text
[NR_OP_SPLIT, left_pc, right_pc]
```

Epsilon branch to two targets.

### `NR_OP_MATCH`

```text
[NR_OP_MATCH, 0, 0]
```

Accept state. Reaching this state means the VM has found a successful match.

## Matching model

This first executor uses Thompson-style NFA simulation with:

- a current state set
- a next state set
- epsilon-closure expansion through an explicit stack
- per-closure visit marking to avoid duplicate epsilon traversal

## Context / scratch storage

The executor receives caller-owned scratch arrays:

- `current_states`
- `next_states`
- `mark_tokens`
- `epsilon_stack`

For the current bytecode subset:

- `current_states.length >= instruction_count`
- `next_states.length >= instruction_count`
- `mark_tokens.length >= instruction_count`
- `epsilon_stack.length >= instruction_count`

The executor may mutate these arrays freely during a run.

The executor must not allocate replacement arrays during execution.

## Input model

The current bytecode subset matches raw string bytes using:

```ruby
string.getbyte(pos)
```

No multibyte character semantics are defined yet.

## Allocation rules

Allowed to allocate:

- program construction
- test harness construction
- runner setup
- caller-owned scratch arrays before entering the executor

Not allowed to allocate:

- executor run path
- epsilon closure expansion
- transition loop
- callback result transport

## Worked examples

### Example 1: `ab`

Pattern:

```text
ab
```

Program:

```text
pc 0: [NR_OP_CHAR, 97, 1]   # 'a'
pc 1: [NR_OP_CHAR, 98, 2]   # 'b'
pc 2: [NR_OP_MATCH, 0, 0]
```

Flat array:

```ruby
[
  1, 97, 1,
  1, 98, 2,
  5, 0, 0
]
```

Expected behavior:

- return value: `true`
- callback:
  - `nr_on_match(0, 2, 0)`

### Example 2: `a|b`

Program:

```ruby
[
  4, 1, 2,
  1, 97, 3,
  1, 98, 3,
  5, 0, 0
]
```

Expected behavior on input `"b"`:

- return value: `true`
- callback:
  - `nr_on_match(0, 1, 0)`

## 0C. Runner Contract

The standalone runner is a wrapper around the executor.

It is not part of the executor.

### Runner input contract

The first runner accepts:

```text
run_vm.rb OPCODE_CSV INPUT [START_POS]
```

Where:

- `OPCODE_CSV` is a comma-separated flat integer instruction array
- `INPUT` is the input string
- `START_POS` is an optional decimal integer start position

This is only the current bytecode subset input format. Later revisions may replace it
with binary formats or compiled-program files.

### Runner output contract

The runner output is line-oriented and deterministic.

On successful match:

```text
match,<start_pos>,<end_pos>,<capture_count>
status,1
```

On failure:

```text
status,0
```

Rules:

- `match,...` lines are emitted by the callback stub owned by the runner
- `status,...` is emitted by the runner after the executor returns
- line ordering is part of the contract
- output must be identical between CRuby and Spinel-native execution for the
  same inputs

### Validation target

The runner contract is the primary black-box validation mechanism for:

- CRuby correctness checks
- Spinel equivalence checks
- later allocation-free inspection of the compiled path

## Current Subset Exit Criteria

The current subset is complete when:

- the callback contract is explicitly defined
- the executor / runner boundary is explicit
- the opcode encoding is fixed for the first subset
- scratch-array ownership rules are explicit
- runner input and output formats are deterministic
- the spec is concrete enough that the implementation does not invent new
  semantics
