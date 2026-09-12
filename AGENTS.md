# AGENTS.md — math-coding v1.0 runtime hint

You are working in a math-coding v1.0 repository. The convention
guides how decisions are documented as packets. Every non-trivial
decision lives under `math/<name>/`.

## What math-coding is

math-coding is a discipline for documenting decisions. A packet
records:

1. **Proposition** — what was decided (one sentence, falsifiable).
2. **Antithesis** — the strongest objection (recommended).
3. **Synthesis** — how thesis and antithesis resolve (recommended
   when antithesis exists).
4. **Intent** — what success looks like (recommended).
5. **What this is NOT** — anti-claims (optional).
6. **Worked example** — concrete instance (optional).
7. **Run** — executable specification (optional, enables `shell`
   or `pbt` substrate).
8. **Notes** — free-form (optional).

The packet lives in `math/<name>/packet.md`. Witness history lives
in `math/<name>/witness`. Substrate-specific files (TLA+, Coq,
Alloy) live in `math/<name>/<substrate>/`.

## The seven axioms

  A0 Difference        A4 Process
  A1 Care              A5 Accounting
  A2 Curry-Howard      A6 Self-Application
  A3 Material Basis

A3 (Material Basis) reads: plain text for human content, git for
state, single static binary for tools. No per-project framework
install.

## Three lifecycle states (computed)

  draft       — no witness
  applied     — witness + files in witness commit
  drift       — proposition changed after witness
  retired     — explicit retire (via CLI)
  abandoned   — explicit abandon (via CLI)

Lifecycle is **computed** from git history. Optional `status:`
field in frontmatter **overrides** the computation.

## Eight substrates

  none        — only proposition, no executable verification
  shell       — run shell command, verify exit code
  tla+        — TLA+ state-machine spec (TLC)
  coq         — Coq formal proof (coqc)
  alloy       — Alloy relational constraint
  pbt         — property-based tests (QCheck-style)
  bpmn        — BPMN workflow (XML well-formedness)
  pbt-prism   — probabilistic PBT (Prism)

Substrate is chosen by the LLM based on
`docs/substrate-decision-rules.md`. Real verification is
implemented for `none`, `shell`, `pbt` in v1.0. Other substrates
report `tool not installed, SKIP` until external checkers are wired.

## Five epistemic markers

  fact        — verified by evidence
  hypothesis  — suspected, not proven
  judgment    — decision, do not argue
  unknown     — do not know
  proven      — evidence reproduces (re-runnable command)

`proven` requires reproducible evidence. Verify re-runs the
recorded command and compares exit code. If mismatch, marker
demotes to `hypothesis`.

## Workflow

When the user asks for a non-trivial change:

1. Read context (issue, code, related packets).
2. Form a proposition: one sentence, falsifiable.
3. Form an antithesis: strongest objection.
4. Form a synthesis: how both resolve.
5. Choose a substrate: read `docs/substrate-decision-rules.md`.
6. Run `sh scripts/install.sh` (one-time, builds and installs
   the OCaml binary to `$XDG_DATA_HOME/math-coding/`).
7. Run `math-coding packet create <name> --proposition="..."
   --antithesis="..." --synthesis="..."`.
8. Implement the operation in code.
9. Commit: `git add . && git commit -m "<name>: <short desc>"`.
10. Run `math-coding check` — verifies structure + lifecycle.
11. Optionally run `math-coding review <name> --approve`.
12. Run `math-coding probe` — axiom Self-Application.

When the proposition changes: create a new packet with
`--supersession=math/<old-name>/`. Do not edit the old packet.

## Packet structure (v1.0)

```
math/<name>/
├── packet.md        # YAML frontmatter + Markdown body
├── witness          # YAML list of witness entries
├── run.sh           # only if substrate: shell
├── properties/      # only if substrate: pbt
├── tla/             # only if substrate: tla+
├── coq/             # only if substrate: coq
├── alloy/           # only if substrate: alloy
└── bpmn/            # only if substrate: bpmn
```

## Witness file format

```yaml
- sha: abc1234...
  date: 2026-09-15
  kind: amendment       # or: supersession
  files: [src/cache.py, tests/cache_test.py]
- sha: def5678...
  date: 2026-10-01
  kind: supersession
  superseded_by: math/cache-ttl-v2/
```

## Commands

  math-coding packet create <name> --proposition="..."
                                   [--antithesis="..."]
                                   [--synthesis="..."]
                                   [--intent="..."]
                                   [--files=path1,path2]
                                   [--substrate=none|shell|pbt|...]
                                   [--supersession=math/<name>]
  math-coding packet edit <name>    [--proposition="..."]
                                   [--antithesis="..."]
                                   [--clear=antithesis]
                                   [--status=applied|retired|abandoned]
                                   [--substrate=...]
  math-coding packet show <name>
  math-coding packet list
  math-coding packet substrate <name> <level>
                                   # adds substrate-specific files

  math-coding check                 [--epistemics] [--json]
  math-coding drift
  math-coding probe                  # axiom Self-Application
  math-coding install                # builds OCaml, installs to $XDG_DATA_HOME
  math-coding upgrade                # rebuilds from source

## Reading order

1. `AGENTS.md` — this file
2. `docs/axioms.md` — seven axioms
3. `docs/theories.md` — theories
4. `docs/substrate-decision-rules.md` — when to use each substrate
5. `math/<latest-packet>/packet.md` — most recent decision

Resolve the latest packet with:

  git log --oneline -- math/ | head -1
