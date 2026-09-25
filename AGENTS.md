# AGENTS.md — protocol for AI agents in math-coding v2.1

This packet documents how AI agents (LLM-driven coding tools) should
interact with a math-coding project. The protocol is auto-installed
by `mathc init` and supersedes the previous v2.0-Y AGENTS.md.

## When to record a decision

If a code change is more than a typo or rename — if a reviewer
would reasonably ask "why this and not that" — record a packet:

```sh
mathc decide NAME "single-sentence proposition" --register=judgment \
  --antithesis="..." --synthesis="..."
```

This single command creates the packet, commits it, sets the
witness, and commits the witness. Done.

For trivial changes (renames, typos, formatting), just commit —
no packet needed.

## Frontmatter (10 fields)

```yaml
---
schema_version: "2.1"                 # V7: mandatory
name: <unique-name>                    # mandatory
proposition: "<one-sentence claim>"   # V1: mandatory, non-empty
register: fact|hypothesis|judgment|unknown  # V3: mandatory
state: draft|applied|reviewed|retired|abandoned  # V4: mandatory
actor: human|agent|system             # V5: mandatory
confidence: <0.0-1.0>                 # mandatory; bounded by register
kind: axiom|policy|fix|experiment     # for filtering; default: policy
superseded_by: <name>|""              # only present when superseded
beneficiary: <enum>|Other(text)       # optional (default: System)
---
```

## Body sections

For `register: judgment` packets, the following sections are
**required** (V7: dialectic-tas):

- `## Why` — motivation, one paragraph
- `## Antithesis` — strongest objection
- `## Synthesis` — how thesis and antithesis resolve

For `register: hypothesis`/`fact`/`unknown` packets, body is free
Markdown. Empty body is allowed.

## Commands

```sh
mathc decide NAME "prop" [opts]   # one-step: create + commit + amend + commit
mathc record NAME "prop"          # legacy: two-step (record, commit, amend, commit)
mathc amend NAME                  # set witness to current HEAD
mathc supersede OLD NEW "..."     # replace decision; auto-retires OLD
mathc mark-superseded OLD NEW     # link OLD to existing NEW (no NEW create)
mathc archive NAME                # move to math/archived/<year>/<month>/
mathc note "comment"              # trivial packet (no witness, register=unknown)
mathc check                       # verify all packets
mathc list                        # only active (default)
mathc list --all                  # including archived
mathc find <substr>               # search proposition
mathc show <name>                 # full packet (frontmatter + body)
mathc history <name>              # git log + supersession chain
mathc graph <name>                # mermaid supersession graph
mathc stats                       # applied/retired breakdown
```

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
mathc check                     # structure + lifecycle + FSM + register + dialectic + cycles
mathc check --json              # machine-parseable
```

A `Fail` verdict means the convention was violated. Common fixes:

- `V4 Fail` (state=draft but witness present): run `mathc amend NAME`
- `V7 Fail` (judgment missing dialectic): add `## Why`/`## Antithesis`/`## Synthesis`
- `V6 Fail` (supersession cycle): remove the cycle via `mark-superseded`

## Supersession (V6 SPO)

When proposition changes, never edit `packet.md` in place. Use:

```sh
mathc supersede OLD NEW "new proposition"
# or, if NEW already exists:
mathc mark-superseded OLD NEW
```

Supersession is a strict partial order (irreflexive, asymmetric,
transitive). Cycles are detected by V6.

## Sane defaults (.mathrc is optional)

Without `.mathrc`, defaults apply:

- `SIGNING_MODE: off` (signatures not checked)
- `AUTO_AMEND: true` (decide auto-commits witness)
- `FACT_POLICY: warn` (agent+fact without evidence is a warning)
- `DIALECTIC_REQUIRED.judgment: [Why, Antithesis, Synthesis]`

Override via `.mathrc` if you need strict signing, fail-on-fact, or
custom dialectic requirements.

## Self-application

The five foundations (`math/{curry-howard,temporal,constructive,categorical,motivation}`)
and three extensions (`math/{process-fsm,dialectic-tas,actor-discipline}`)
are themselves packets. `mathc check` verifies them with the same
kernel. Convention applies to itself: this protocol is part of
the convention's invariant.

## Source of truth

The canonical source for this protocol is the
`agents-protocol-v2-1` packet in `math/`. Edit that packet via
`supersede`, not the rendered file.
