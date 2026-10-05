# Foundations

> **From axioms to OCaml.** Each foundation is a packet
> under `decisions/` that maps an axiom to a kernel
> mechanism and a verification obligation.

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

## The extensions

The three extensions add kernel surface without changing the
five foundations:

| Extension | Surface | Cram fixture |
|-----------|---------|--------------|
| `mathc-explain-subcommand` | `mathc explain decision:foo` → `{kind,id,digest,path,body}` | `explain-{positive,negative}.t` |
| `mathc-self-check-subcommand` | `mathc self-check` → JSON verdict | `self-check-{pass,fail,unknown}.t` |
| `mathc-packages-subcommand` | `mathc packages --format=text\|json\|html` → package list | `packages.t` |

The kernel at v3.1.0-alpha ships the eight foundations. The
site at [Packages](packages.html) is the live verdict of all
29 active decisions.