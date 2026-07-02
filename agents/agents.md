# Notes for AI agents

If you are an AI coding agent asked to follow the math-coding
convention, this file tells you the minimum you need to know.

## Read first

Read `core/core.md` completely before opening a packet. Do not
skip. Do not skim. The document is the single source of truth,
grounded in the 8 theory documents in `core/01-Theory/`.

## Epistemics as Action Protocol

This is the most important section. Read it carefully.

When you read an `assumptions.yaml` entry, you must apply this
protocol based on the `epistemology` field:

| Epistemology | Belief interval | Your action |
|--------------|------------------|--------------|
| `judgment` | $\{0, 1\}$ discrete | **Respect, do not challenge.** Treat as design decision. Do not propose alternatives without explicit user request. |
| `unknown` | $0$ | **Ask user, do not proceed.** Mark `status: open` if not already. |
| `fact` | $1.0$ | **Verify if possible** (read source, run check). If cannot verify, downgrade to `hypothesis` with low confidence. |
| `hypothesis` | $(0, 1)$ | **Search for evidence** (tool, doc, prior packet). If found: upgrade to `fact` with high confidence. If not: keep as `hypothesis`. If contradicted: downgrade to `unknown` and ask user. |

**Always record**: source of evidence, confidence level, timestamp.

This protocol is **not optional**. Without it, epistemic
markers are merely cosmetic. See
[theory-07-epistemic](../core/01-Theory/07-Epistemic.md) for
the formal definition.

## Two-layer scheme

The convention distinguishes between **mandatory** and
**auto-inferred** epistemic markers:

**Mandatory (cannot be auto-inferred):**

- `judgment` — design decision, requires human input
- `unknown` — open question, requires human input

**Auto-inferred (agent may set):**

- `fact` — agent sets when confident (e.g., source verified)
- `hypothesis` — agent sets when uncertain (default)

If you encounter a packet where mandatory markers are missing,
**ask the user** before proceeding.

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
  [theory-06-verdict](../core/01-Theory/06-Verdict.md).

## Process for opening a packet

1. Read `core/core.md`.
2. Check existing packets in `./math-coding/tasks/` (if any).
   If the task overlaps, update that one.
3. Decide whether the task is non-trivial (judgment-based).
4. Create the packet directory.
5. Copy template files from `examples/hello/`.
6. Fill in `task.md` (Problem, Desired outcome, Constraints).
7. Fill in `assumptions.yaml` with **at least four assumptions**.
   Apply the epistemic protocol: judgment and unknown for
   design decisions and open questions; fact and hypothesis
   for technical claims. Set confidence numerically.
8. Fill in `packet.yaml`. Set `owner`, `priority`, `tags`.
   If the task has a deadline, set `target_completion`.
9. If the task warrants a model, write `Model.tla` and
   `Model.cfg`.
10. If the task warrants a verifier, write `verify*.sh` and
    ensure it produces a `verifier-output.yaml` with all
    provenance fields.
11. Write `refinement.md` with the five required sections.
12. Write `traceability.json` linking model elements to code.
13. Run the verifier. Read the output. Promote lifecycle only
    if the verifier succeeded.

## Lifecycle awareness

Every packet carries a `lifecycle` field in `packet.yaml`. The
five values move through a state machine — see
[theory-02-state-machine](../core/01-Theory/02-State-Machine.md).

- **sketch** — `task.md` and `assumptions.yaml` exist. Your
  job is to fill them with intent.
- **working** — `Model.tla` or `verify.sh` exists. Your job is
  to run the verifier and let the verdict land.
- **verified** — `verifier-output.yaml.verdict == VERIFIED`.
  Treat as read-only unless the user explicitly asks.
- **deprecated** — packet is acknowledged as no longer
  reflecting current code. `supersession.yaml` records the
  supersession.
- **archived** — preserved for historical reference. Immutable.

If you want to move a packet backwards (e.g., `verified →
working` on counterexample), the FSM allows it. **Update
`lifecycle_history`** if the field is present.

## Defaults

- `substrate: tla` for state machines, async coordination,
  protocol-like behavior.
- `substrate: typescript` for TS/JS projects.
- `substrate: shell` for shell-based tools.
- `substrate: none` for sketch packets.
- `decision: needed` if you opened the packet.
- `priority: medium` if not specified.

## Architecture decision records

If the project has ADRs (in `adr/`), read the most recent
ones before opening a packet. They may constrain your decision.
If your packet contradicts an existing ADR, either update the
ADR or explain why this packet is an exception.

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
`task.md` under a new section `# Decisions made under
ambiguity`. This is your epistemic trail.