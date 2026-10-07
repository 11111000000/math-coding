# math-coding 3.0-alpha

> Author: Petr Kosov <p.b.kosov@yandex.ru>
> Status: 3.0-alpha, current release v3.1.0-alpha. Bootstrap gate
> expired at v3.0.0.19 (2026-09-29). The 3.2-ideal algebra
> (`spec/algebra-3.2.md`) is normative alongside the prose specs.
> License: Apache-2.0 (see `LICENSE`, `NOTICE`).
> Ethics: [`ETHICS.md`](ETHICS.md).

Math-coding is a protocol that ties every change to a written
commitment, a list of obligations, and bounded evidence that they
hold. It is for teams who want their CI to refuse a change for a
named rule, not a vague feeling. It does not prove software correctness.

## The chain

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

- **intent**: what should become true.
- **decision**: a written commitment, recorded under the active policy.
- **obligation**: what the decision promises; each one names a fixture.
- **change**: the diff that implements the decision.
- **attestation**: bounded evidence that the obligation holds.
- **revision**: the next decision that updates or supersedes the last.

The kernel checks the chain. Humans write it.

## Why bootstrap-gate expiry matters

Before v3.0.0.19, every change had to satisfy eight manual bootstrap
checks in lieu of a working kernel. From v3.0.0.19 onward,
`mathc self-check` is a blocking CI step. The kernel is now the
authoritative source of the verdict on a clean tree. The verdicts
are bounded by the source class of each attestation in the store
(`kind_` ∈ `test | review | build | analysis | observation`); a
`review`-class attestation is a human declaration, not a runtime
observation, so "verdict: pass" reflects that every obligation has
at least one attestation — it does not by itself assert that every
attestation is a `test`-class automated check. Routine checks are
free; protected-policy transitions keep the manual checklist on top.

## CLI

| Subcommand | Purpose |
|---|---|
| `mathc validate FILE` | Schema check on a decision |
| `mathc context BASE HEAD --budget N` | Bounded context capsule for an agent |
| `mathc explain REF` | Resolve a `kind:id` reference to its body |
| `mathc explain-diagnostic CODE` | Describe an `MC-*` diagnostic code |
| `mathc assess BASE HEAD` | List changed files between two git refs |
| `mathc attest FILE` | Import a JUnit XML report as JSON |
| `mathc gate BASE HEAD` | Assurance verdict for the diff |
| `mathc self-check` | Kernel passes its own repository + corpus |
| `mathc packages` | Index of decisions, obligations, verdicts |
| `mathc render` | Build the static site under `dist/` |
| `mathc time-estimate` | Honest duration claim from a reference class |
| `mathc mode PATH ...` | 3.2-ideal risk classification (algebra §2) |
| `mathc rebuttals SHA` | Walk `rebuttals/<sha>.yaml` (algebra §10) |
| `mathc re-evaluate DEC AXIOM` | Re-evaluation oracle (algebra §17) |
| `mathc re-evaluate-decisions AXIOM` | Walk decisions/ and emit post-run verdicts + attestations (T1.2, algebra §17) |
| `mathc version` | Print the bootstrap hello and exit 0 |
| `mathc session-start` | Write `.local/session-start` ISO timestamp |
| `mathc record --decision-id ID ...` | Append event to `decisions/execution-logs.jsonl` |
| `mathc stats [--class N] [--scale S]` | Emit empirical aggregate JSON |

Full catalog and exit codes: [`spec/semantics.md`](spec/semantics.md).

## Pointers

- [`AGENTS.md`](AGENTS.md): agent protocol. Read first.
- [`ROADMAP.md`](ROADMAP.md): priority queue and process principles.
- [`PACKAGES.md`](PACKAGES.md): what exists in this repository.
- [`spec/constitution.md`](spec/constitution.md): 14 invariants the kernel preserves.
- [`axioms/`](axioms/index.md): A0 separation, A1 feedback, A2 invariants, A3 self-application, A4 care.
- [`site/`](site/): published surface, built by `mathc render` and
  deployed to [GitHub Pages](https://11111000000.github.io/math-coding/)
  by `.github/workflows/site.yml`.
- [`USAGE.md`](USAGE.md): adoption runbook.