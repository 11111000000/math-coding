# math-coding 3.7

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/11111000000/math-coding?sort=semver)](https://github.com/11111000000/math-coding/releases/latest)
[![Subcommands](https://img.shields.io/badge/subcommands-34-blueviolet)](PACKAGES.md)
[![Site](https://img.shields.io/website?url=https%3A%2F%2F11111000000.github.io%2Fmath-coding%2F)](https://11111000000.github.io/math-coding/)

> Author: Petr Kosov <p.b.kosov@yandex.ru>
> Status: 3.7.4, current release v3.7.4. Bootstrap gate
> expired at v3.0.0.19 (2026-09-29). The 3.2-ideal algebra
> (`spec/algebra-3.2.md`) is normative alongside the prose specs.
> License: Apache-2.0 (see `LICENSE`, `NOTICE`).
> Ethics: [`ETHICS.md`](ETHICS.md).
> Kernel implementation: OCaml. Runtime is a portable binary — users of math-coding in other languages do not need OCaml, `dune`, `nix`, or any tool listed below.

## Are you applying math-coding to your own project?

If yes, **stop reading this file** and go to [`adoption/SKILL.md`](adoption/SKILL.md).
That is the only document you need. Everything else in this repository — this
README, `KERNEL_AGENTS.md`, `OCAML_KERNEL_CONVENTIONS.md`, `spec/`, `axioms/`,
`lib/`, `bin/` — exists for the people who maintain the math-coding kernel
itself. Random reading will surface OCaml-specific conventions that do not
apply to your project.

The math-coding kernel is the OCaml program that implements the protocol
(`mathc` CLI, schemas, conformance runner). Adopters do not compile it; they
download a binary from the [GitHub release](https://github.com/11111000000/math-coding/releases/latest)
and run `mathc` against their own (Go / Python / Rust / JS / anything) project.


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
| `mathc attest-batch` | Generate attestation JSONs from TSV manifest or by walking decisions |
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
| `mathc forge-verify [--org ORG] [--team TEAM] [--user USER]` | Query forge_mirror for committer team membership |
| `mathc counters` | Live counters JSON (decisions, obligations, attestations, cram, CLI) |
| `mathc init [PATH] [--agent NAME] [--from-adr PATH] [--no-install] [--merge]` | Scaffold new math-coding project |
| `mathc import-adr PATH [--write]` | Convert existing MADR/adr-tools ADR to a math-coding decision |
| `mathc adopt [PATH] [--only=CONV] [--dry-run]` | Detect existing ADR corpus and offer merge path |
| `mathc new-decision <id> [--write] [--interactive] [--force]` | Scaffold a decision YAML from canonical template |
| `mathc rehash [--write] [--dry-run] [PATH...]` | Recompute `body_sha`/`yaml_sha` from each file's own bytes |
| `mathc telemetry status` | Print telemetry state (Phase 2 stub) |
| `mathc migrate --from=X --to=Y [--root=DIR] [--format=text|json] [--explain] [--manifest=PATH] [--write|--dry-run]` | Declarative migration plan reader |

Full catalog and exit codes: [`spec/semantics.md`](spec/semantics.md).

## Pointers — **for kernel maintainers**

These are not for adopters. If you are applying math-coding to your own
project, [`adoption/SKILL.md`](adoption/SKILL.md) is the only document you
need; everything below is documentation for the people who maintain the
math-coding kernel itself.

- [`KERNEL_AGENTS.md`](KERNEL_AGENTS.md): kernel-maintainer protocol. Renamed from `KERNEL_AGENTS.md` at v3.3.3; the OCaml, `dune`, `nix` content was previously here and is still here.
- [`OCAML_KERNEL_CONVENTIONS.md`](OCAML_KERNEL_CONVENTIONS.md): OCaml conventions for `lib/`, `bin/`, `tests/`, plus the §11 trap log. Renamed from `OCAML_KERNEL_CONVENTIONS.md`.
- [`ROADMAP.md`](ROADMAP.md): priority queue and process principles.
- [`PACKAGES.md`](PACKAGES.md): what exists in this repository.
- [`spec/constitution.md`](spec/constitution.md): 14 invariants the kernel preserves.
- [`axioms/`](axioms/index.md): A0 separation, A1 feedback, A2 invariants, A3 self-application, A4 care.
- [`site/`](site/): published surface, built by `mathc render` and
  deployed to [GitHub Pages](https://11111000000.github.io/math-coding/)
  by `.github/workflows/site.yml`.
- [`QUICKSTART.md`](QUICKSTART.md): first read (kernel maintainers, not adopters — adopters use `adoption/SKILL.md`).
- [`USAGE.md`](USAGE.md): full runbook.