---
schema_version: "2.0"
name: agents-protocol
proposition: "AI agents working on a math-coding project record non-trivial decisions as packets through mathc record + amend; the convention describes protocol via the same kernel that verifies user packets."
register: judgment
state: applied
actor: system
confidence: 1.0
superseded_by:
beneficiary: developer
---

# math-coding — protocol for AI agents in math-coding v2.0-Y

This packet documents how AI agents (LLM-driven coding tools) should
interact with a math-coding project. The protocol is auto-installed
by `mathc init` and supersedes the previous v2.0 AGENTS.md.

## When to record a decision

If a code change is more than a typo or rename — if a reviewer
would reasonably ask "why this and not that" — record a packet.

```sh
mathc record NAME "single-sentence proposition"
git add math/NAME/ && git commit -m "NAME: short description"
mathc amend NAME              # set witness to current HEAD
git add math/NAME/witness && git commit -m "NAME: witness"
mathc check
```

If the change is trivial, just commit — no packet needed.

## Frontmatter (9 fields)

```yaml
---
schema_version: "2.0"                 # V7: mandatory
name: <unique-name>                    # mandatory
proposition: "<one-sentence claim>"   # V1: mandatory, non-empty
register: fact|hypothesis|judgment|unknown  # V3: mandatory
state: draft|applied|reviewed|retired|abandoned  # V4: mandatory
superseded_by: <name>|""              # V6: mandatory (empty if none)
actor: human|agent|system             # V5: mandatory
confidence: <0.0-1.0>                 # mandatory; bounded by register
beneficiary: <enum>|Other(text)       # optional (default: System)
---
```

## Body sections

For actor=human or register=judgment packets, the following
sections are required (V5: dialectic-tas):

- ## Why — motivation, one paragraph
- ## Care — ethical consideration (reversibility, mitigation)
- ## Thesis — proposition in full
- ## Antithesis — strongest objection
- ## Synthesis — how thesis and antithesis resolve

## Six lifecycle verdicts

- `Pass` — packet is structurally valid
- `Warn` — convention recommends action
- `Fail` — convention violated; fix before commit
- `Skip` — packet skipped by configuration

Lifecycles: `Draft` (no witness) → `Applied` (witness matches
proposition) → `Drift` (proposition changed after witness) →
`Stale` (witness commit unreadable).

## Verify

```sh
mathc check                     # structure + lifecycle + FSM + register + actor
mathc check --json              # machine-parseable
```

A `Fail` verdict means the convention was violated. Fix with
`mathc supersede NAME NAME-v2 "new proposition"` (creates new
packet, marks old as superseded).

## Navigate

```sh
mathc list                       # all packets with lifecycle
mathc find <substring>           # search by name/proposition
mathc grep <pattern>             # grep over proposition
mathc show <name>                # full packet (frontmatter + body)
mathc history <name>             # git log + supersession chain
mathc graph <name>               # mermaid supersession diagram
mathc stats                      # drift rate, applied/total, chains
```

## State transitions (V4 FSM)

States: `draft` → `applied` → `reviewed` → `retired | abandoned`.

Use `mathc transition NAME <state>` or `mathc review NAME`
(alias for `transition reviewed`). The transition `draft → reviewed`
without witness is forbidden (V4 Fail).

## Supersession (V6 SPO)

When proposition changes, never edit `packet.md` in place. Use:

```sh
mathc supersede OLD NEW "new proposition"
git add math/NEW/ && git commit -m "NEW: ..."
mathc amend NEW
git add math/NEW/witness && git commit
```

Supersession is a strict partial order (irreflexive, asymmetric,
transitive). Cycles are forbidden.

## Three signing modes

Set in `.mathrc` (`SIGNING_MODE`):

- `strict`: every witness commit must be GPG/SSH signed
- `lenient`: only the amend commit needs a signature (default)
- `off`: signatures ignored

Agent decisions (`actor: agent`) with `register: fact` trigger
a Warn (V5). Use `register: hypothesis` for agent-recorded claims
that lack re-runnable evidence.

## Self-application

The five foundations (`math/{curry-howard,temporal,constructive,categorical,motivation}`)
and three extensions (`math/{process-fsm,dialectic-tas,actor-discipline}`)
are themselves packets. `mathc check` verifies them with the same
kernel. Convention applies to itself: this protocol is part of
the convention's invariant.

## Source of truth

The canonical source for this protocol is the `AGENTS.md` file at
the project root, generated from this packet by `mathc render`.
Edit this packet via `supersede`, not the rendered file.