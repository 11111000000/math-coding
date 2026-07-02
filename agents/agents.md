# Notes for AI agents

If you are an AI coding agent asked to follow the math-coding
convention, this file tells you the minimum you need to know.
For deeper detail, see `agents/process.md` and
`agents/rigor-tools.md`.

## Read first

Read `core/core.md` completely before opening a packet. Do not
skip. Do not skim. The document is the single source of truth,
grounded in 8 theory documents in `core/01-Theory/`.

Advanced theories in `core/02-Theory-advanced/` apply only at
`rigor: proof+`. Read them when the project uses advanced
formal tools (Coq, dependent types).

## Five-step process

1. **Decide rigor.** Pick the level that matches the task
   (light / property / temporal / relational / proof / bpmn).
   See `agents/rigor-tools.md`. Default: `light`.
2. **Create packet.** Run `sh .opencode/commands/mathpacket <id>`
   from the project root. The script reads `.mathcodingrc` for
   `packets_dir` (default `specs/`).
3. **Fill content.** Write `task.md`, `assumptions.yaml`,
   `packet.yaml`. Apply the epistemic protocol (see below).
4. **Add rigor artifacts.** If rigor > light, write `Model.*`
   and the corresponding `verify-*` script.
5. **Run verifier.** Run the structural verifier; promote
   lifecycle only if verdict is VERIFIED.

For the full 13-step process, see `agents/process.md`.

## Epistemics as Action Protocol

When you read an `assumptions.yaml` entry, apply this protocol
based on the `epistemology` field:

| Epistemology | Belief interval | Your action |
|--------------|------------------|--------------|
| `judgment` | $\{0, 1\}$ discrete | **Respect, do not challenge.** Treat as design decision. Do not propose alternatives without explicit user request. |
| `unknown` | $0$ | **Ask user, do not proceed.** Mark `status: open` if not already. |
| `fact` | $1.0$ | **Verify if possible** (read source, run check). If cannot verify, downgrade to `hypothesis` with low confidence. |
| `hypothesis` | $(0, 1)$ | **Search for evidence** (tool, doc, prior packet). If found: upgrade to `fact` with high confidence. If not: keep as `hypothesis`. If contradicted: downgrade to `unknown` and ask user. |

**Always record**: source of evidence, confidence level, timestamp.

This protocol is **not optional**. Without it, epistemic
markers are merely cosmetic. See
`core/01-Theory/07-Epistemic.md` for the formal definition.

## Two-layer scheme

**Mandatory (cannot be auto-inferred):**

- `judgment` — design decision, requires human input
- `unknown` — open question, requires human input

**Auto-inferred (agent may set):**

- `fact` — agent sets when confident (e.g., source verified)
- `hypothesis` — agent sets when uncertain (default)

If you encounter a packet where mandatory markers are missing,
**ask the user** before proceeding.

## Lifecycle awareness

Every packet carries a `lifecycle` field in `packet.yaml`. The
five values move through a state machine — see
`core/01-Theory/02-State-Machine.md`.

- **sketch** — task.md and assumptions.yaml exist. Your job
  is to fill them with intent.
- **working** — Model.tla or verify.sh exists. Your job is to
  run the verifier and let the verdict land.
- **verified** — verifier-output.yaml.verdict == VERIFIED.
  Treat as read-only unless the user explicitly asks.
- **deprecated** — packet is acknowledged as no longer
  reflecting current code. `supersession.yaml` records the
  supersession.
- **archived** — preserved for historical reference. Immutable.

If you want to move a packet backwards (e.g., verified →
working on counterexample), the FSM allows it. Update
`lifecycle_history` if the field is present.

## Where packets live

In **self-application** mode (this repository), packets live
wherever the convention places them.

In **external-project** mode, packets live in a dedicated
directory, configured via `.mathcodingrc` in the project root:

```yaml
# .mathcodingrc
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