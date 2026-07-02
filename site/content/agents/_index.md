---
title: "Notes for AI agents"
description: "Agent instructions"
---

packets_dir: specs   # or: math
convention_version: 2.1.0
```

Default: `specs/`. The agent must **read `.mathcodingrc`
first** before creating or locating packets.

## Rigor levels

Math-coding supports six rigor levels. Higher rigor requires
more formal artifacts but provides stronger guarantees.

| Rigor | Marker files | When to use |
|-------|--------------|-------------|
| `light` | `verify.sh` | Default. Structural checks only. |
| `property` | `verify-property.sh` | Property-based testing (fast-check, jqwik). |
| `temporal` | `Model.tla` + `verify-tlc.sh` | TLA+. State machines, async, distributed protocols. |
| `relational` | `Model.als` + `verify-alloy.sh` | Alloy. Structural/relational invariants. |
| `proof` | `Model.v` + `verify-coq.sh` | Coq. Constructive proofs of propositions. |
| `bpmn` | `Model.bpmn` + `verify-bpmn.sh` | BPMN. Business processes. |

The agent detects rigor by **file presence**, not by
configuration. If `verify.sh` exists, rigor is at least light.
If `Model.tla` and `verify-tlc.sh` exist, rigor is at least
temporal. See `agents/rigor-tools.md` for the full reference.

## Rules that are easy to get wrong

- **Closed convention.** Do not invent file names or field
  names. The convention is the files in `core/core.md` and the
  schema for each. If you find yourself wanting to add
  `packet.yaml.flow`, `packet.yaml.flow.md`, or similar, stop
  and ask the human first.
- **Always required files.** `packet.yaml`, `task.md`,
  `assumptions.yaml`. A packet without all three is not a
  packet.
- **Epistemics are required, not optional.** Every assumption
  needs `status` and `epistemology`. Use the action protocol
  above.
- **Don't open packets for trivial tasks.** If the task is a
  one-line change, fix it directly. Use judgment for the
  threshold.
- **Don't keep packets in `sketch` forever.** A `sketch` packet
  is a starting point. If the task warrants a formal model,
  write `Model.tla`. If it warrants a verifier, write `verify.sh`.
- **Verifier output is mandatory for `verified`.** If
  `verifier-output.yaml` does not exist or its verdict is not
  `VERIFIED`, the packet is not verified.
- **Verifier output must include provenance.** `verified_at`,
  `scope`, `tool`, `evidence` — see
  `core/01-Theory/06-Verdict.md`.

## Defaults

- `substrate: shell` for shell-based tools.
- `substrate: typescript` for TS/JS projects.
- `substrate: tla` only when rigor is `temporal`.
- `substrate: coq` only when rigor is `proof`.
- `substrate: alloy` only when rigor is `relational`.
- `substrate: bpmn` only when rigor is `bpmn`.
- `substrate: none` for sketch packets.
- `decision: needed` if you opened the packet.
- `priority: medium` if not specified.

## What not to do

- Do not create a CLI or framework. The convention is
  conventions only.
- Do not add fields to `packet.yaml` that are not in
  `core/core.md` or the schema.
- Do not promote lifecycle from `working` to `verified` without
  running the verifier.
- Do not write `verifier-output.yaml` manually. The verifier
  must produce it.
- Do not mark assumptions as `judgment` or `unknown` without
  human confirmation. These are mandatory markers.

## When you are stuck

Read `core/core.md` again. If it does not answer the question,
the methodology is silent on that point and you may proceed as
you see fit, but **document your decision** in the packet's
`task.md` under `# Adaptations`. This is your epistemic trail.