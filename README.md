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
`mc self-check` is a blocking CI step. The kernel is now the source
of the verdict. `mc gate`, `mc self-check`, and `mc assess` are
automated guarantees, not hand-written promises. Routine checks are
free; protected-policy transitions keep the manual checklist on top.

## CLI

| Subcommand | Purpose |
|---|---|
| `mc validate FILE` | Schema check on a decision |
| `mc context BASE HEAD --budget N` | Bounded context capsule for an agent |
| `mc explain REF` | Resolve a `kind:id` reference to its body |
| `mc assess BASE HEAD` | List changed files between two git refs |
| `mc attest FILE` | Import a JUnit XML report as JSON |
| `mc gate BASE HEAD` | Assurance verdict for the diff |
| `mc self-check` | Kernel passes its own repository + corpus |
| `mc packages` | Index of decisions, obligations, verdicts |
| `mc render` | Build the static site under `dist/` |
| `mc time-estimate` | Honest duration claim from a reference class |
| `mc mode PATH ...` | 3.2-ideal risk classification (algebra §2) |
| `mc rebuttals SHA` | Walk `rebuttals/<sha>.yaml` (algebra §10) |
| `mc re-evaluate DEC AXIOM` | Re-evaluation oracle (algebra §17) |
| `mc version` | Print the bootstrap hello and exit 0 |
| `mc session-start` | Write `.local/session-start` ISO timestamp |
| `mc record --decision-id ID ...` | Append event to `decisions/execution-logs.jsonl` |
| `mc stats [--class N] [--scale S]` | Emit empirical aggregate JSON |

Full catalog and exit codes: [`spec/semantics.md`](spec/semantics.md).

## Pointers

- [`AGENTS.md`](AGENTS.md): agent protocol. Read first.
- [`ROADMAP.md`](ROADMAP.md): priority queue and process principles.
- [`PACKAGES.md`](PACKAGES.md): what exists in this repository.
- [`spec/constitution.md`](spec/constitution.md): 14 invariants the kernel preserves.
- [`axioms/`](axioms/index.md): A0 separation, A1 feedback, A2 invariants, A3 self-application, A4 care.
- [`site/`](site/): published surface, built by `mc render` and
  deployed to [GitHub Pages](https://11111000000.github.io/math-coding/)
  by `.github/workflows/site.yml`.
- [`USAGE.md`](USAGE.md): adoption runbook.