# Foundations

> **From axioms to OCaml.** Each foundation is a packet
> under `decisions/` that maps an axiom to a kernel
> mechanism and a verification obligation. The five axioms
> align with the five bootstrap decisions that gate the
> repository at v3.0.0.19 and onward:

![The five axioms on the left, paired with the bootstrap decisions they enforce on the right: A0 Separation -> bootstrap-v3, A1 Feedback -> attestation-store-fill, A2 Invariants -> kernel-conformance-runner, A3 Self-application -> mathc-self-check-subcommand, A4 Care -> validate-and-context. Footer: "Each axiom is operationalised by a specific decision the kernel checks; the axioms are not aspirational."](assets/axiom-graph.svg)

Each row of the diagram above corresponds to one of the five
sections that follow. The diagram is the spec; the sections
below are the implementation.

## A0 — Separation → `bootstrap-v3`

**Axiom.** Kinds are distinct; the chain goes one way.
`intent ≠ decision ≠ obligation ≠ change ≠ attestation ≠
observation ≠ revision`.

**Mechanism.** Sealed variants in `lib/domain.ml` for each
kind; per-document prefix hints; closed `additionalProperties`
in JSON Schemas under `schemas/`. The parser refuses any
document whose id does not match the closed set declared in
the per-schema file.

**Verification.** `decisions/mathc-packages-subcommand.yaml`
obligation `packages-kernel-walker` enumerates every decision
in the repository and emits a typed JSON; the walker
crashes on a kind that is not in the closed set.

The A0 diagram (shown in the axiom-graph above) is itself an
exercise of A0: each axiom and each decision is a distinct
kind. The diagram is not a flowchart of the protocol; it is a
provenance map of the constraints.

## A1 — Feedback → `attestation-store-fill`

**Axiom.** Every commitment has a path to an observation:
`commitment → prediction → observation → revision`. Without
an observation the commitment is a wish.

**Mechanism.** `attestations/*.json` records every
decision-obligation pair as a `pass | fail | stale |
unknown | missing | no_store` verdict. `lib/attestations.ml`
loads the store and joins each entry against the kernel's
gate.

**Verification.** `scripts/generate-attestations.py`
produces 94 attestation files on every release; `mathc gate
BASE HEAD` reports `gate-pass.t` / `gate-fail.t` /
`gate-stale.t` as green (cram fixtures under `tests/cli/`).

The attestation lifecycle diagram (rendered at the bottom of
this page) shows the five stages that turn a CI run into a
verdict: production captures the substrate fingerprint, store
writes the attestation document, join pairs the entry with
its obligation, verdict composes the per-obligation results
into a single disposition, and expiry flips an obligation to
`Inconclusive` when its `valid_until` is reached. The A1 axiom
says every commitment has such a path; the lifecycle is the
path.

## A2 — Invariants and Recovery → `kernel-conformance-runner`

**Axiom.** For every invariant `I`, a recovery operator
`R` is authorized. The remedy is finite.

**Mechanism.** `lib/gate.ml` evaluates each obligation
against the attestation store and emits typed
`Gate.gap` records with `causes` and `remedies`. The
kernel never blocks a merge without naming a remedy.

**Verification.** `tests/conformance.ml` enumerates every
fixture and asserts the runner never crashes; `mathc
self-check` returns `pass` on clean `main` HEAD.

The `kernel-conformance-runner` decision binds A2 to the
`tests/conformance.ml` executable. Every fixture in the
conformance corpus is paired with a corresponding `mc-*` type
code in `lib/diagnostic.ml::explain`. If the runner crashes,
the gap message names the registry entry that the runner
expected to consume — a typed call-out, not a backtrace.

## A3 — Self-application → `mathc-self-check-subcommand`

**Axiom.** The rules govern their own changes:
`(K_n, P_n) → (K_{n+1}, P_{n+1})` requires Gate Open,
Conformance Pass, Migration round-trips, VerdictDiff
within DeclaredSemanticChanges, SelfVerify Pass.

**Mechanism.** `mathc self-check` walks every decision in
`decisions/` and emits a JSON verdict that names the
kernel that produced it (SHA-256 of the binary) and the
repository digest. The verdict is gated on the **current**
rules, before the lock is promoted.

![A3 Self-application: the (kernel, policy) pair is its own gate. Two states (K_n, P_n) and (K_{n+1}, P_{n+1}) connected by a transition. Guard conditions: Gate = Open, Conformance = Pass, Migration = Pass, VerdictDiff subset of DeclaredSemanticChanges, SelfVerify = Pass.](assets/a3-self-application-flow.svg)

The diagram above is a visualisation of the A3 axiom. A3 says
that the kernel must check its own upgrade path: the rules
that gate `(K_n, P_n) → (K_{n+1}, P_{n+1})` are the same rules
that gate any other transition. The five guards in the diagram
are the pre-conditions the kernel enforces on itself before
publishing a new release.

**Verification.** `tests/cli/self-check-{pass,fail,unknown}.t`
green; `decisions/mathc-self-check-subcommand.yaml` obligation
`mathc-self-check-dispatcher-shipped` is met.

## A4 — Care → `validate-and-context`

**Axiom.** For every commitment: who benefits, who suffers,
who is accountable, when will it be revisited.

**Mechanism.** `decision.risk.owner`, `obligation.decision`,
`assumption.owner`, `waiver.issuer`,
`attestation.producer_identity` are **required** fields in
their respective schemas. The parser rejects a decision
without an owner.

**Verification.** `fixtures/conformance/decision/negative-*.yaml`
are rejected by `Decision.parse_decision` for missing
required fields; `fixtures/conformance/decision/positive-*.yaml`
are accepted.

A4 is the axiom that ties the other four to humans. A0, A1,
A2, and A3 are all structural — they describe how the kernel
moves bytes around. A4 says the kernel exists because humans
care, and that the humans who care are accountable. The
`validate-and-context` decision names the four required
fields in the schema; without them, the kernel refuses the
artifact.

## The extensions

The three extensions add kernel surface without changing the
five foundations:

| Extension | Surface | Cram fixture |
|-----------|---------|--------------|
| `mathc-explain-subcommand` | `mathc explain decision:foo` → `{kind,id,digest,path,body}` | `explain-{positive,negative}.t` |
| `mathc-self-check-subcommand` | `mathc self-check` → JSON verdict | `self-check-{pass,fail,unknown}.t` |
| `mathc-packages-subcommand` | `mathc packages --format=text\|json\|html` → package list | `packages.t` |

The kernel at v3.3.0-alpha ships the eight foundations plus
the 3.2-ideal algebra on top of them. The site at
[Packages](packages.html) is the live verdict of every
active decision; the live build currently reports 93 active
decisions / 330 obligations (313 pass / 16 missing / 1 unknown).

## The supporting diagrams

The following figures are the visual vocabulary the rest of
the site uses. Each was drawn in the same Tufte palette so
the protocol's published surface looks consistent across pages.

![Attestation lifecycle: production, store, join, verdict, expiry. Five stages from a CI run to a gate verdict.](assets/attestation-lifecycle.svg)

The attestation lifecycle is the concrete shape of A1: every
commitment has a path to observation, and the path is
production → store → join → verdict → expiry. The five
stages are exactly the five rows of the
`attestation-store-fill` decision; the diagram is what the
decision looks like in motion.

![Counterexample flow: author writes a counterexample set in decision.yaml; the kernel checks |C(D)| >= 1 for any decision whose mode is not tiny; on absence the gate blocks the merge and emits a remediation. Counterexample is the machine-checkable forcing function; antithesis is the coherent counter-position the author engaged with (algebra section 11, 11.1).](assets/counterexample-flow.svg)

The counterexample flow is the concrete shape of the
`counterexample` slot in the dialectic method. A1 says every
commitment must have a path to observation; the counterexample
slot is the path the author provides before the kernel
publishes the decision.

![Axiom transition: the re_evaluate(d, A_new) oracle returns one of three ReEvaluationStatus values -- Compatible, Inconclusive, StaleClaim -- and the gate verdict is the max_verdict across the impact-list (algebra section 17).](assets/axiom-transition.svg)

The axiom-transition flow is the concrete shape of the
`re-evaluate-decisions` obligation. A3 says the rules
govern their own changes; `re-evaluate(d, A_new)` is the
mechanism the kernel uses to test a change to the rules
before adopting it.

![Trust dynamics: the Liar paradox resolves at a single hop -- a node trusts only its own observation and the next node's observation, never the next node's claim; the system is sound because a claim only propagates through observed claims, and an observed claim is by definition honest.](assets/trust-dynamics.svg)

The trust-dynamics diagram is the underlying graph theory of
A1. Each node trusts only its own observation and the next
node's observation; claims propagate only through observed
claims. A1 is the axiom; the trust-dynamics diagram is the
graph that satisfies it.

![Substrate fingerprint: the kernel digests a substrate (decision store, attestations store, active policy) into a single sha256, the fingerprint. Two substrates are equivalent under A0 if and only if their fingerprints match; the kernel will not entertain the question "are these the same?" by any means other than fingerprint equality.](assets/substrate-fingerprint.svg)

The substrate-fingerprint diagram is the formal counterpart
to A0. Kinds are distinct; the substrate's identity is the
fingerprint that distinguishes it from any other substrate.
Two substrates are equivalent under A0 if and only if their
fingerprints match.

![Waiver state machine: the waiver FSM has four states -- Active, Grace, Expired, Revoked -- and three transitions. A waiver enters Grace when its valid_until is reached; a waiver enters Expired when grace is exhausted; a waiver enters Revoked when the issuing human revokes it. The decision the waiver modifies is held in StaleClaim during Grace and Expired and the kernel refuses to gate any artifact that depends on it during those states.](assets/waiver-state-machine.svg)

The waiver state machine is the concrete shape of the
`waiver-infrastructure-2026-10` decision. A waiver is a
human's statement that an obligation does not apply to a
specific change; the FSM records the waiver's lifecycle and
the kernel refuses to gate any artifact that depends on a
waiver in a non-Active state.

![Friction envelope: risk (x-axis) versus lines of code changed (y-axis) for the four rungs of the friction ladder. Silent envelope is the smallest box, block is the largest. Mode is the ceiling: a change's mode is the smallest envelope that contains its position. The envelope is small for typo fixes, large for schema changes; the kernel picks the friction level that matches the envelope.](assets/friction-envelope-plot.svg)

The friction-envelope plot is the geometry of the `risk`
function. Mode is the smallest envelope that contains the
change's `(risk, lines_changed)` position; the friction level
is the rung whose envelope matches the change's mode. A
typo fix sits inside the silent envelope; a schema change
sits inside the block envelope.

![Quality radar: six axes for measuring change quality (correctness, scope, alignment, attestation, recovery, cost). Each axis is 0 to 1; the kernel emits one score per axis per gate run. A change is acceptable when all six are above the policy-declared floor; the floor is shown as a hexagon. The radar plot overlays the floor over the current scores so a reviewer can see at a glance which axes are below threshold.](assets/quality-radar.svg)

The quality radar is the visualisation of the
`change-quality` obligation. Each axis is a different facet of
change quality; the floor is set by the policy. A reviewer
who wants to know why a change was rejected can read the
radar and see which axis fell below the floor.

![Three independent time-reporting scales: wall-clock-minutes, token-budget, step-count. The three are independently observable and may not be combined into a single natural-language estimate (AGENTS.md section Honest time reporting; algebra section 18).](assets/reasoning-budget.svg)

The reasoning-budget diagram enforces the project's honest
time-reporting rule. The three scales (wall-clock minutes,
token budget, step count) are independently observable; the
kernel reports all three and refuses to combine them into a
single natural-language estimate. The figure shows the three
scales as separate axes; a reviewer who wants to know how
much "time" a change took has to read all three.
