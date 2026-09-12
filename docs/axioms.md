# Seven Axioms (math-coding v1.0)

math-coding is grounded on seven axioms. Each axiom is realised as
a packet under `math/<axiom-name>/`.

## A0. Difference (ontological)

**Statement**: A proposition differs from its implementation.

The proposition lives in `math/<name>/packet.md`. The implementation
lives in `src/`, `lib/`, or wherever the project's own convention
dictates. The gap between them is what math-coding observes.

**Packet**: `math/00-difference/`

## A1. Care (motivational)

**Statement**: A developer cares whether the code does what it
claims.

Without care, no amount of structure helps. A packet filled with
placeholder text and a verifier that passes it is the failure mode
A1 forbids.

**Packet**: `math/01-care/`

## A2. Curry-Howard (structural)

**Statement**: A packet is a spec; the code is an impl; the
witness is the correspondence.

If `files: [src/foo.py, tests/foo_test.py]` is set, verify checks
that witness commit changed these files. This makes Curry-Howard
a **verifiable** claim, not a metaphor.

**Packet**: `math/02-curry-howard/`

## A3. Material Basis (substrate)

**Statement**: Plain text for human content, git for state, single
static binary for tools.

No per-project framework install. The packet is a YAML/Markdown
file. History is git. Tooling is one static binary at
`$XDG_DATA_HOME/math-coding/<ver>/`.

**Packet**: `math/03-material/`

## A4. Process (temporal)

**Statement**: Process precedes code. Lifecycle is computed.

The lifecycle (`draft / applied / drift / retired / abandoned`) is
**derived** from git history. A witness without files changed is
`stale`. A proposition changed after witness is `drift`. Optional
`status:` field overrides the computation.

**Packet**: `math/04-process/`

## A5. Accounting (epistemic)

**Statement**: Marked knowledge is reproducible when `proven`.

Five markers (`fact / hypothesis / judgment / unknown / proven`).
`proven` requires evidence with a re-runnable command. Verify
re-runs the command and compares exit code. On mismatch, marker
demotes to `hypothesis`.

**Packet**: `math/05-accounting/`

## A6. Self-Application (meta)

**Statement**: The convention applies to itself.

Each axiom above is realised as a packet. The probe verifies that
axiom packets satisfy structural and epistemic checks. The tool
that proves A6 holds is itself the subject of a packet.

**Packet**: `math/06-self-application/`

## Order of dependency

```
A0 (ontological) → A1 (motivational) → A2 (structural) →
A3 (substrate)   → A4 (temporal)     → A5 (epistemic)  →
A6 (meta)
```
