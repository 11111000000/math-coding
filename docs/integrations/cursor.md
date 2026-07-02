# Cursor Integration

This document describes how math-coding works with Cursor,
the AI-first IDE. The convention is grounded in mathematical
theories that agents can use as reasoning context.

## TL;DR

Add `.cursorrules` at the repo root. Cursor reads this file
when generating code. The content tells the Cursor agent to
apply math-coding invariants and the epistemic action protocol.

```text
# .cursorrules (summary)
Read core/core.md and agents/agents.md before any action.
Apply the epistemic action protocol from agents/agents.md §"Epistemics as Action Protocol".
For non-trivial tasks (4+ assumptions), open a packet following core/core.md.
After edits, run sh examples/self-application/verify-consistency.sh.
```

## The `.cursorrules` file

Place this content at the root of your math-coding repository:

```
# math-coding — Cursor Integration

You are working in a math-coding repository.

## What this convention is

A packet-based methodology for software development. Every
non-trivial change is captured as a "packet" — a directory
with packet.yaml, task.md, assumptions.yaml, and (for verified
packets) refinement.md, traceability.json, verifier-output.yaml.
The convention is grounded in 8 mathematical theories (see
core/01-Theory/).

## MANDATORY: Read these files before doing anything

- core/core.md — the convention itself
- agents/agents.md — what AI agents should do
- core/01-Theory/01-Predicate-and-Invariant.md (skim)

## MANDATORY: Apply the epistemic action protocol

When you read an `assumptions.yaml` entry, look at the `epistemology`
field. Apply this protocol:

- `judgment`: respect, do not challenge. Do not propose
  alternatives without explicit user request.
- `unknown`: ask user, do not proceed. Mark `status: open` if not.
- `fact`: verify if possible. Downgrade to `hypothesis` if can't.
- `hypothesis`: search for evidence. Upgrade to `fact` on find.
  Downgrade to `unknown` if contradicted.

## MANDATORY: Use the packet lifecycle

Every task lifecycle is `sketch → working → verified →
deprecated → archived`. See core/core.md §"State machine".

The lifecycle transitions are FSM:
- sketch → working: add Model.tla or verify.sh
- working → verified: verifier returned VERIFIED
- verified → working: verifier returned non-VERIFIED

Do NOT promote lifecycle without verifier output.

## MANDATORY: Run the verifier before claiming success

After making changes:

```sh
sh examples/self-application/verify-consistency.sh
```

If output starts with `OK:` — claim success.
Otherwise — fix the violations before claiming success.

## DO NOT

- Do not invent file names or field names not in core.md or schemas/
- Do not write verifier-output.yaml manually (verifier writes it)
- Do not mark assumptions as `judgment` or `unknown` without
  human confirmation
- Do not skip the packet for trivial changes (uses judgment per
  ADR-0002)
- Do not commit without a successful verifier run

## Reference

See agents/agents.md for the full agent manual.
```

## How Cursor uses `.cursorrules`

Cursor reads `.cursorrules` automatically when you open a
chat in the IDE. The file becomes part of the agent's system
prompt. Every agent invocation in that workspace sees these
instructions.

## How math-coding makes Cursor smarter

The mathematical theories in `core/01-Theory/` provide
**reasoning primitives** that a generic agent lacks:

- **Predicate logic** lets the agent reason about invariants
  explicitly.
- **FSM formalism** lets the agent reason about state machine
  bugs (race conditions, deadlocks).
- **LTL operators** let the agent state liveness properties.
- **Refinement maps** let the agent verify that implementation
  matches spec.
- **Epistemic logic** lets the agent handle belief updates
  systematically instead of guessing.

A Cursor agent with these theories plus a packet-based
workflow is **substantially more rigorous** than a generic
Cursor agent. Math-coding is not a checklist; it's an
**epistemic upgrade** for the agent.

## Specific Cursor commands

### Verify before commit

Add a Cursor command (`.cursor/commands/verify.md`):

```markdown
Run the math-coding verifier.

Steps:
1. Run `sh examples/self-application/verify-consistency.sh`
2. If it fails, list the violations and suggest fixes
3. If it passes, run `sh examples/schema-self-application/verify-schemas.sh`
4. Report all violations

This command returns:
- "OK" if everything passes
- A list of issues otherwise
```

Use this command via `Cmd+K` → "verify". The verifier will
run; you'll see all violations.

### Open a packet

`.cursor/commands/open-packet.md`:

```markdown
Open a new math-coding packet.

Steps:
1. Read core/core.md §"Packet structure"
2. Run `sh .opencode/commands/mathpacket <id>` to create the packet (template is built into the command)
3. Fill in packet.yaml (using the schema)
4. Fill in task.md (Problem, Desired outcome, Constraints)
5. Fill in assumptions.yaml (4+ entries with epistemic markers)
6. Optionally write refinement.md and traceability.json

Get the task description from the user.
```

### Promote lifecycle

`.cursor/commands/promote-packet.md`:

```markdown
Promote a packet's lifecycle.

Steps:
1. Determine current lifecycle
2. Determine target lifecycle (user-provided)
3. Check if transition is legal (see core/core.md §"State machine")
4. Check required artifacts for the new state
5. Run the verifier
6. If everything passes, update packet.yaml.lifecycle

Refuse to promote if the transition violates the FSM (e.g.,
sketch → verified is forbidden).
```

## Cursor context and the math-coding theory

When Cursor generates a TLA+ model or a TypeScript reducer,
the agent can pull from `core/01-Theory/` for grounding:

```
User: "Model a modal dialog state machine"
Cursor: reads core/01-Theory/02-State-Machine.md, sees the formal
        definition of FSM, then writes Model.tla following the
        Math.tla pattern. Reads 03-Temporal-Logic.md to add liveness.
```

This is the **math-coding superpower**: the IDE agent has
access to formal specifications via the workspace files,
not via its training data alone.

## Anti-patterns

- **Editing `.cursorrules` to bypass verifier.** The verifier
  is what makes math-coding rigorous. Don't tell Cursor to
  skip it.
- **Embedding secrets in `.cursorrules`.** It's checked in. Use
  environment variables or CI secrets.
- **Per-developer `.cursorrules`.** Convention violations are
  silent. Use branch protection.

## What this does NOT do

- **Cursor cannot enforce packet lifecycle.** The verifier
  enforces it. Cursor can suggest the workflow but cannot
  guarantee it.
- **Cursor cannot replace a human reviewer.** It accelerates
  work but the merge decision is human.

## Setup

1. Save the rules above as `.cursorrules` at the repo root.
2. Commit it.
3. Done. Cursor agents in this workspace will read it on every
   invocation.

## References

- Cursor documentation:
  <https://docs.cursor.com>
- AI-agent integration patterns:
  See `agents/agents.md` in this repository.