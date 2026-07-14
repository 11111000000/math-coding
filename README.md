# math-coding

> A **Curry-Howard convention**: every packet is a **proof
> term**, every verifier exit-code is a **type-check**. The
> convention applies to itself.

## What is this

math-coding is a plain-text + git + POSIX-shell convention
where every non-trivial decision is a **packet** — a directory
with five files. The packet is the proposition; the code is
the proof term; the verifier is the type-checker; the proof
resolves through `sh core/ops/probe.sh` exit-code.

## Four axioms

1. **think-before-do** — model first, code second.
   See `core/think-before-do.md`.

2. **FSM lifecycle** — every packet is `sketch → working →
   verified → deprecated → archived`, with `superseded`
   as a parallel terminal edge. Transition `sketch →
   verified` is forbidden.

3. **epistemic markers** — every assumption has one of:
   `fact | hypothesis | judgment | unknown | proven`.

4. **axiom A4** — the convention applies to itself.
   `sh core/ops/probe.sh` exit 0 is the recursive
   observability witness. Marker `epistemology: proven`
   is reserved for this and similar end-to-end checks.

## Eight theories (4 foundational + 4 applied)

Foundational:

1. `curry-howard` — proposition ↔ type.
2. `predicate` — every check is a predicate `I: S → B`.
3. `fsm` — lifecycle is a finite state machine.
4. `refinement` — packet = spec, code = impl, relation R.

Applied:

5. `verdict` — five outcomes of verifier (VERIFIED /
   NEEDS_REVISION / UNVERIFIABLE:*).
6. `epistemic` — five markers, `confidence ∈ [0,1]`.
7. `deprecation` — supersession is a strict partial order.
8. `agent` — LLM as a runtime substrate (mode, role).

## Three modes (proportional rigor)

| Mode | When | Required artefacts |
|------|------|---------------------|
| `light` | typo, doc fix | commit + 1-line rationale |
| `standard` | new feature | 5-file packet |
| `strict` | architecture | packet + theory-link + applications[] |

Default by role: developer→`standard`, designer/PM→`light`,
researcher→`strict`, tech-writer→`skip`.

## Five-file packet

```
math/<name>/
├── packet.yaml       # manifest + applications[]
├── decision.md       # thesis / synthesis (+antithesis if feature)
├── task.md           # problem / outcome / constraints
├── assumptions.yaml  # Σ with epistemic markers
└── refinement.md     # state / operation / invariant / test
```

## Universal: one convention, depth scales

Small project: 1-2 packets/week, mostly `light` mode.
Large project: 100+ packets, `standard` and `strict` modes.
**Same convention, different depth.**

## Self-application

This repository IS a math-coding repository:

- `core/theories/` — the eight theories.
- `math/<name>/` — every decision is a packet.
- The repository proves axiom A4 by `sh core/ops/probe.sh`
  resolving to exit-code 0 against itself.

## License

Living Beings — see LICENSE.

## Read first (for agents)

1. This file (root manifest).
2. `core/think-before-do.md`.
3. `core/decision-modes.md`.
4. `core/packet-schema.md`.
5. `math/<latest>/decision.md` (resolve via `git log --oneline math/*/decision.md | head -1`).