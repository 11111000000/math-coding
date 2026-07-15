---
name: math-coding
description: math-coding v0.854 convention for AI coding agents. Seven axioms, 5-file packet, three modes, six lifecycle states. Use when the user mentions math-coding, packets, or convention-bootstrap install.
license: Living Beings License
metadata:
  audience: AI coding agents
  workflow: convention-application, decision-tracking, spec-driven-development
  version: 0.854
---

# math-coding v0.854

Curry-Howard convention for AI coding agents. Plain text,
git, POSIX. The convention applies to itself (axiom
Self-Application).

## Seven axioms

| Axiom | Question it answers |
|-------|---------------------|
| A0 Difference | What is a proposition vs. an implementation? |
| A1 Care | Why does the convention matter? |
| A2 Curry-Howard | How does a packet relate to a proof? |
| A3 Material Basis | What substrate does the convention run on? |
| A4 Process | When does a packet become verified? |
| A5 Accounting | How does the convention track what it knows? |
| A6 Self-Application | Does the convention apply to itself? |

Read `references/axioms.md` for full axiom statements.
Read `references/theories.md` for the eight theories that
ground them.

## Read first

1. `README.md` — one-page manifest
2. `references/axioms.md` — seven axioms (load on demand)
3. `references/theories.md` — eight theories (load on demand)
4. `math/<latest-packet>/decision.md` — most recent decision

## Five files per packet (axiom A2 + axiom A3)

  packet.yaml       manifest, lifecycle, applications[]
  decision.md       proposition (thesis / antithesis / synthesis)
  task.md           intent (problem / outcome / constraints)
  assumptions.yaml  epistemic context (5 markers)
  refinement.md     state / operation / invariant / test / runtime

## Three modes (axiom A4)

  light     — commit message only (typo, doc fix)
  standard  — full 5-file packet (most changes)
  strict    — packet + theory link + applications[]

## Six lifecycle states (axiom A4)

  sketch → working → verified → deprecated → archived
                                            ↑
                                            superseded

Forbidden: `sketch → verified`. Run `references/lifecycle.md`
for FSM details.

## Eight commands

  sh math-coding init <name>       scaffold 5-file packet (template)
  sh math-coding create <name>     create from YAML spec (one call)
  sh math-coding extract <name>    emit YAML spec to stdout
  sh math-coding verify            structural + axioms + theories check
  sh math-coding drift-check       applications[] SHA vs HEAD
  sh math-coding probe             axiom Self-Application
  sh math-coding install <path>    install into a brownfield project
  sh math-coding uninstall <path>  remove install

For examples of full YAML specs, see `examples/cache-ttl-spec.yaml`.

## When things go wrong

- `verify.sh` fails: read the FAIL line, fix the file, re-run.
- `probe.sh` fails: 6 checks, find the failing one, fix it.
- drift detected: refresh applications[] SHA, commit.
- new axiom needed: add to `docs/axioms.md` AND create
  `math/<NN-axiom>/` packet AND link from this skill.

## init vs create

- `init <name>`: template mode. Five files with placeholder
  content. You fill them in.
- `create <name> --from <spec.yaml>`: spec-driven. Five files
  with content from the spec. One call.

When to use which:
- `init`: you don't have a spec yet; you think as you write.
- `create`: you have a spec (or the user gave you one). One
  call produces 5 files.

## create with heredoc (most common for LLM agents)

```bash
sh math-coding create my-feature --from - <<'EOF'
name: my-feature
mode: standard
thesis: "The feature does X."
antithesis: "Some claim that contradicts X."
synthesis: "X is true because Y."
surface_impact: "touches: my-feature [FLUID]"
proof: "tests/contract/test_my_feature.spec"
problem: "What problem does this solve?"
outcome: "What does success look like?"
constraints:
  - must be testable
assumptions:
  - id: A1
    statement: "<your first assumption>"
    status: user-confirmed
    epistemology: fact
    confidence: 0.95
    evidence: "<one-line evidence>"
state:
  pre: <pre-state>
  post: <post-state>
operation: "<what the agent does>"
mapping: "<spec state to impl state>"
invariant: "<what stays true>"
test_obligation: "<how to verify>"
runtime_check: "<how to monitor>"
EOF
```

## Writing good packets (axiom Process + axiom Accounting)

A good thesis is **specific** ("reduce latency by 30%"),
**falsifiable** (it can be wrong), and **one sentence**
(avoid "and"). A good antithesis is the **strongest
objection**, not a strawman. A good synthesis **explains
how the choice was made**, not just that it was.

When the proposition itself changes, **do not edit the
old packet**. Create a new packet with `supersession:`
pointing at the old one.

See `examples/cache-ttl-spec.yaml` for a full example.

## Modes of operation

When the user asks for a non-trivial change:

  sh math-coding init my-feature
  # fill the five files
  git add math/my-feature
  git commit -m "my-feature: first commit"
  sh math-coding verify

When the user asks about an axiom, cite the axiom packet
under `math/<NN-axiom>/` and the theory under `theories/`.

When the user asks about the convention's own state, run
`sh math-coding probe`. If it returns 0, axiom Self-Application
holds.