# Math-coding 3.0-alpha

> Project author: Petr Kosov <p.b.kosov@yandex.ru>
> License: Apache-2.0 (see `LICENSE`, `NOTICE`)
> Ethics: non-binding (see `ETHICS.md`)

Math-coding is a risk-adaptive assurance protocol for software
changes. It links intent, decisions, obligations, changes,
attestations, observations, and revisions.

## Working chain

```text
intent -> decision -> obligation -> change -> attestation -> revision
```

## Operational chain

```text
change -> affected_knowledge -> assurance_gaps -> minimal_remedies -> gate
```

Math-coding does not prove software correctness. It determines whether
a concrete change satisfies the assurance requirements declared by
the active project policy.

## Current status: 0.0.1 (bootstrap)

- `spec/`: constitution, domain, semantics.
- `schemas/`: canonical JSON Schemas for Decision, Obligation,
  Attestation, Waiver.
- `fixtures/conformance/`: positive and negative fixtures covering
  bootstrap invariants.
- `lib/`: minimal OCaml core, SHA-256, JSONL parser, decision
  decoder. Compiles, but exposes only a bootstrap message.
- `bin/mathc.exe`: prints "math-coding 3.0-alpha: bootstrap".

Not yet implemented:

- `mc assess`, `mc gate`, `mc explain`, `mc validate` commands.
- Git/JUnit adapters.
- Context compiler.
- MCP server.

The 2.1 implementation has been removed from the active tree. Its
source is preserved by the remote tag `v2.1-final`.

## For agents

Read `AGENTS.md` before modifying anything.

## Foundations

The mathematical and philosophical basis is in `axioms/`. Every
non-trivial change is derived from at least one axiom:

- [A0 Separation](axioms/separation.md)
- [A1 Feedback](axioms/feedback.md)
- [A2 Invariants](axioms/invariants.md)
- [A3 Self-application](axioms/self-application.md)
- [A4 Care](axioms/care.md)

See [axioms/index.md](axioms/index.md) for the entry point and the
table linking each axiom to the kernel properties that enforce it.
