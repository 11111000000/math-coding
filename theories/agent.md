# Agent (axiom Self-Application)

An AI coding agent is a function over a state space:

```
S = (chat_history, files_read, files_written, mode, role)
```

The agent reads and writes files, proposes actions, and may
ask clarifying questions. Its actions form a trace:

```
trace = [(read, file), (propose, mode), (write, file), ...]
```

## math-coding instance

In math-coding:

```
agent mode   ∈ { skip, light, standard, strict }
agent role   ∈ { developer, designer, product-manager,
                researcher, tech-writer }

agent reads  AGENTS.md, docs/axioms.md, theories/*.md,
             math/<packet>/

agent writes math/<packet>/<file>.md, optionally with
             packet.yaml:applications[] entries
```

axiom Self-Application is the convention closing the
loop: an agent runs the convention on the convention.

## Modes and roles

**Modes** govern how much ceremony a change requires:

  skip      — no record (rare; deprecated)
  light     — commit message only
  standard  — full 5-file packet (most changes)
  strict    — packet + theory link + applications[]

Default by role:
  developer          →  standard
  designer           →  light
  product-manager    →  light
  researcher         →  strict
  tech-writer        →  skip (or light)

## What an agent does

The agent's trace is its proof term. The convention treats
the trace as an executable. The verifier evaluates the
**result** of the trace (the files written, the packets
created), not the trace itself.

The agent's type-checker is `core/check/verify.sh` and
(in axiom Self-Application) `core/self/probe.sh`. The trace is correct
iff the verifier exits 0 on the resulting state.

## Why it matters

An agent that operates without a convention is a writer
without a style guide. It produces plausible output; the
output does not fit into the convention's structure; the
verifier rejects it; the agent retries with no progress.

A convention-aware agent produces output that fits the
structure from the first try. The agent's first commit is
already a packet. The agent's first review is already a
verifier run.

axiom Self-Application makes this explicit: the agent **is** the
convention's interpreter. The convention's structure is the
agent's instruction set. The agent's output is the
convention's content.

## Where this lives

  `math/06-self-application/` — the axiom that defines
                              what the agent is.
  `theories/agent.md` — this file.
  `AGENTS.md` — runtime hint for any agent.
  `extensions/agents/opencode/SKILL.md` — OpenCode skill.
## Theorem

An agent is a deterministic function over the state
S = (chat_history, files_read, files_written, mode, role).

## Proof

By definition: every agent action is a function
trace = [(read, file), (propose, mode), (write, file), ...].
The agent's mode and role are fixed at session start
(loaded from AGENTS.md and .mathrc). The agent's state
is fully determined by S. axiom Self-Application
verifies that the agent's output satisfies the convention's
verifier. □
