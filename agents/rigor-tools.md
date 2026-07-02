# Rigor tools reference

Math-coding supports six rigor levels. Each level is
**detected automatically** by the verifier through file
presence, not declared in configuration.

## Detection rules

The agent and the verifier look for these markers in the
packet directory:

| Rigor | Required files |
|-------|----------------|
| `light` | `verify.sh` (default — any packet with a verifier has at least this) |
| `property` | `verify-property.sh` (in addition to `verify.sh`) |
| `temporal` | `Model.tla` + `verify-tlc.sh` |
| `relational` | `Model.als` + `verify-alloy.sh` |
| `proof` | `Model.v` + `verify-coq.sh` |
| `bpmn` | `Model.bpmn` + `verify-bpmn.sh` |

If multiple rigor levels are present (e.g., both `Model.tla`
and `Model.v`), the **highest** rigor applies. The agent
should report which rigor it inferred when describing the
packet.

## When to use which rigor

### `light` (default)

- What it gives you: structural checks only (required files,
  valid YAML, FSM transitions, epistemics markers, lifecycle
  consistency).
- When to use: every packet. This is the floor.
- Tooling: shell + awk + grep + sed + git. Nothing else.
- Time cost: ~1 second per packet.
- Limitation: no behavioral verification. The packet can have
  correct structure and still encode wrong intent.

### `property`

- What it gives you: random-input testing against invariants.
  Catches bugs that structural checks miss but does not prove
  absence of bugs.
- When to use: pure functions, parsers, validators, anything
  with clear input/output.
- Tooling: `jqwik` (Java/Kotlin), `fast-check` (JS/TS),
  Hypothesis (Python), QuickCheck (Haskell).
- Time cost: 1-30 seconds per property.
- Limitation: not exhaustive. Coverage depends on shrinking
  and generator quality.

### `temporal`

- What it gives you: exhaustive model checking of state
  machines and protocols. Can prove safety and liveness
  properties over all reachable states.
- When to use: distributed systems, concurrent code,
  protocols, anything with non-trivial state transitions.
  See `examples/modal-dialog/` for a reference.
- Tooling: TLA+ Toolbox, TLC model checker, Apalache (symbolic).
- Time cost: 1-60 minutes per model (state-space dependent).
- Limitation: requires writing a TLA+ model separately from
  the implementation. Refinement map (`refinement.md`) must
  show the model maps to code.

### `relational`

- What it gives you: exhaustive search over relational
  structures. Catches structural inconsistencies that
  temporal logic misses (e.g., "no orphan references",
  "every user has at most one active session").
- When to use: data models, schemas, configuration validity,
  anything that fits the relational paradigm.
- Tooling: Alloy Analyzer.
- Time cost: seconds to minutes (scope-bounded).
- Limitation: bounded by scope; you specify the universe
  size.

### `proof`

- What it gives you: constructive proof that propositions
  hold. Strongest guarantee available. The packet becomes a
  **proof term** in the Curry-Howard sense (see
  `core/02-Theory-advanced/09-Curry-Howard.md`).
- When to use: security-critical code (cryptography,
  authentication), financial transactions, kernel code, any
  place where a bug costs more than the proof effort.
- Tooling: Coq, Lean, Isabelle/HOL, Agda, F\*, Dafny,
  Creusot (Rust), Kani (Rust model checker).
- Time cost: hours to weeks per proposition.
- Limitation: requires proof-engineering skill. The agent
  alone cannot write Coq; the user must collaborate.

### `bpmn`

- What it gives you: business process verification. Catches
  deadlocks, missing gateways, unreachable states in
  workflows.
- When to use: enterprise workflows, business processes,
  approval flows, anything human-orchestrated.
- Tooling: Camunda Modeler + Engine, jBPM, Bizagi.
- Time cost: minutes to hours.
- Limitation: BPMN is visual; the formal semantics are
  weaker than TLA+. Use for process-level checks, not
  cryptographic correctness.

## How to pick

Ask these questions in order:

1. **Does this code have a state machine or protocol?** If
   yes, `temporal`. Otherwise continue.
2. **Does this code have relational invariants?** (e.g.,
   "every X references exactly one Y") If yes, `relational`.
   Otherwise continue.
3. **Is this a business process with human steps?** If yes,
   `bpmn`. Otherwise continue.
4. **Is correctness critical (security, finance, safety)?**
   If yes, `proof`. Otherwise continue.
5. **Does this code have interesting input/output behavior
   worth random testing?** If yes, `property`. Otherwise
   `light`.

If still uncertain, default to `light` and upgrade later.
Higher rigor is not always better — it costs more time and
requires more skill. Apply rigor where the cost of bugs is
high.

## How to add a new rigor level

Adding a new rigor level (e.g., `petri-net`) requires:

1. Pick marker files (e.g., `Model.pn` + `verify-pn.sh`).
2. Write a small reference example in `examples/<name>/`.
3. Document in this file (one section).
4. Update `agents/agents.md` (the rigor table).
5. Update `.opencode/skills/math-coding/SKILL.md` (if it
   needs an agent skill).

No schema change is needed (rigor is not declared in
configuration). The verifier does not check rigor presence;
it just detects what is there.

## Common pitfalls

- **Adding rigor without a model.** A packet with `verify.sh`
  but no `Model.*` is rigor: `light`. Adding `verify-tlc.sh`
  without `Model.tla` does not raise rigor. The model file
  is the formal artifact; the verifier just runs it.
- **Mixing rigor artifacts without a bridge.** If you have
  both `Model.tla` and `Model.v`, the refinement map must
  explain how they relate. Otherwise the packet is
  incoherent.
- **Skipping rigor entirely.** A `verified` packet without
  any verifier script and without `UNVERIFIABLE:OUT_OF_SCOPE`
  in its verdict is structurally invalid. The convention
  requires that verification produces a verdict, not that
  the verdict comes from a formal tool.