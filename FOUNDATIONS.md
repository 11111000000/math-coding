# Foundations and extensions

math-coding consists of eight packets: five foundations
(`foundations/`) and three extensions (`extensions/`). All eight are
verified by the same kernel — there is no special path for the
foundations.

## Foundations

### `math/foundations/curry-howard/`

**Thesis.** A decision is a triple (proposition, code, witness); the
kernel $S$ verifies the structural correspondence between proposition
and code through the witness.

**Implementation in OCaml:** the `decision` type in `core/types.ml`
— a direct reflection of the triple from the Curry-Howard
isomorphism. The proposition is a type, the code is a term, the
witness is a derivation.

**When applied:** every packet in the project. The curry-howard
foundation is the data schema.

### `math/foundations/temporal/`

**Thesis.** The lifecycle $L$ of a decision is a function of the
decision and git history; $L$ is computed, not stored.

**Implementation in OCaml:** `Lifecycle.compute : decision ->
lifecycle` in `core/lifecycle.ml`. Returns `Draft | Applied | Drift
| Stale` based on the witness and `git show <sha>:math/<name>/packet.md`.

**When applied:** every time `mathc check` runs. If the proposition
in the witness commit differs from the current one — drift.

### `math/foundations/constructive/`

**Thesis.** The `proven` state requires reproducible evidence:
re-running the command must yield the recorded exit code.

**Implementation in OCaml:** `Repo.run_substrate` in `core/repo.ml`
runs a shell command, records the exit code into a temporary file,
and compares it with `recorded_exit`. On mismatch — drift.

**When applied:** packets with `substrate: shell` or
`substrate: pbt`. Without a substrate, constructive proof is not
required.

### `math/foundations/categorical/`

**Thesis.** Supersession is a strict partial order: irreflexive,
asymmetric, transitive.

**Implementation in OCaml:** `Check.check_supersession` in
`core/check.ml`. Checks that `superseded_by` points to an existing
packet in the `applied` state.

**When applied:** every time `mathc check` runs. Detecting a cycle
yields `Fail`.

### `math/foundations/motivation/`

**Thesis.** Every packet declares an epistemic register
(`fact`/`hypothesis`/`judgment`/`unknown`) and a numerical
confidence. The `why` field (in the `## Why` section) is mandatory
for `judgment`.

**Implementation in OCaml:** `Check.check_motivation` in
`core/check.ml`. Checks that the register is among the permitted
ones, that the confidence lies in [0,1], and that it matches the
register. `why` must be non-empty.

**When applied:** every packet. `why` is mandatory for `judgment`
packets (Warn, not Fail).

## Extensions

### `math/extensions/process-fsm/`

**Thesis.** Decisions exist in five states (`draft`, `applied`,
`reviewed`, `retired`, `abandoned`); the only forbidden transition
is `draft` → `reviewed` without a witness.

**Implementation in OCaml:** `Check.check_fsm` in `core/check.ml`.
Compares the packet's `state` against the presence of a witness. A
forbidden transition yields `Fail`.

**When applied:** every packet with an explicit `state: reviewed`.
Without a witness — rejected.

### `math/extensions/dialectic-tas/`

**Thesis.** Packets with a `judgment` register or a `human` actor
require `## Thesis`, `## Antithesis`, `## Synthesis` sections. The
structural form of dialectic is mandatory for human judgments.

**Implementation in OCaml:** `Check.check_dialectic` in
`core/check.ml`. Parses Markdown sections in the body of
packet.md. The absence of any one yields `Warn`.

**When applied:** every `judgment` or `human` packet. Warn, not
Fail — a recommendation, not a hard requirement.

### `math/extensions/actor-discipline/`

**Thesis.** A decision fixes the author through commit signatures;
the signing mode (`strict`/`lenient`/`off`) is set by the project
through `.mathrc`.

**Implementation in OCaml:** `Repo.run_substrate` plus
`verify_signature` in `core/repo.ml`. Three modes through
`.mathrc: SIGNING_MODE`.

**When applied:** packets with `actor: human` or `actor: agent`.
`strict` → Fail without a signature; `lenient` → Warn; `off` →
ignored.

## Packet structure (9 frontmatter fields)

```yaml
---
schema_version: "2.0"                  # mandatory
name: <unique-name>                    # mandatory
proposition: <one-sentence>            # mandatory, non-empty
register: fact|hypothesis|judgment|unknown  # mandatory
state: draft|applied|reviewed|retired|abandoned  # mandatory
superseded_by: <name>|""               # mandatory (empty if none)
actor: human|agent|system              # mandatory
confidence: <0.0-1.0>                  # mandatory for fact/hypothesis
beneficiary: <enum>|Other(text)         # optional
---
```

The `schema_version` field ensures that the kernel knows which
format plugin to use for parsing. Starting from v2.0 — mandatory.
