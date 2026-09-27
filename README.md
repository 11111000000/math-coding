# Math-coding 3.0-alpha

> Project author: Petr Kosov <p.b.kosov@yandex.ru>
> License: Apache-2.0 (see `LICENSE`, `NOTICE`)
> Ethics: non-binding (see `ETHICS.md`)

Math-coding is a risk-adaptive assurance protocol for software
changes. It links intent, decisions, obligations, changes,
attestations, observations, and revisions.

## Single source of truth

**Read [`ROADMAP.md`](ROADMAP.md) first.** It supersedes any inline
status lists in this file. ROADMAP.md contains the active priority
queue, process principles (P1–P7), and the current audit status.

## Working chain

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

## Operational chain

```text
change -> affected_knowledge -> assurance_gaps -> minimal_remedies -> gate
```

Math-coding does not prove software correctness. It determines whether
a concrete change satisfies the assurance requirements declared by the
active project policy.

## Current status (see ROADMAP.md for live numbers)

- Active tag: `v3-alpha-0.0.14`
- Active policy: `bootstrap-v3@2` (see `bootstrap/decision.yaml`)
- Shell fixtures green: see `ROADMAP.md` §"Status"
- v2.1 implementation removed from active tree; source preserved by
  remote tag `v2.1-final`

## Where things live

| Path | Purpose |
|---|---|
| `ROADMAP.md` | Priority queue, process principles, audit status |
| `AGENTS.md` | Agent protocol (read first, before any edit) |
| `OCAML_BEST_PRACTICES.md` | OCaml conventions + trap log §11 |
| `spec/` | Constitution, domain, semantics (normative) |
| `axioms/` | A0–A4 philosophical foundations (normative) |
| `schemas/` | Canonical JSON Schemas for each artifact kind |
| `bootstrap/` | Active policy and decisions; each decision names its obligation, fixture, verifier |
| `lib/` | Pure OCaml kernel (offline; no I/O) |
| `bin/Mathc.ml` | argv dispatcher and CLI subcommand implementations |
| `lib/git/`, `lib/junit/` | Adapter libraries (may do I/O) |
| `tests/` | Conformance runner (Alcotest) and shell fixtures (`tests/fixtures/`) |
| `scripts/dev` | Build wrapper (replaces `rm -rf _build` superstition) |
| `scripts/check.sh` | Aggregates all `tests/fixtures/*.sh` |
| `doc/AUDIT-0.0.11.md` | Open/closed deficit chain (every deficit tracks a commit hash) |
| `legacy/v2.1.md` | Pointer to the `v2.1-final` tag; v2 source NOT in active tree |

## CLI subcommands

See `spec/semantics.md` §"CLI subcommands" for the authoritative
catalog of `mc validate`, `mc context`, `mc assess`, `mc attest`,
`mc gate`, plus the time-honesty subcommands (`session-start`,
`record`, `stats`, `time-estimate`). `bin/Mathc.ml` is the only
implementation; the spec is the contract.

## For agents

Read `AGENTS.md` first. It enumerates the read-first order, the
bootstrap protocol, and the trap log location. Then read
`ROADMAP.md` §"Priority queue" for what to work on next.

## Foundations

Five normative axioms in `axioms/`:

- A0 Separation — kinds are distinct; chains go one way
- A1 Feedback — every commitment has a path to observation
- A2 Invariants — every invariant has an authorized recovery
- A3 Self-application — the rules govern their own changes
- A4 Care — owner, consequence, accountability required

See [axioms/index.md](axioms/index.md) for the entry point and the
table linking each axiom to the kernel properties that enforce it.
