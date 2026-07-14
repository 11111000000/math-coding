# AGENTS.md — math-coding v0.854 runtime hint

You are working in a math-coding v0.854 repository. Seven
axioms govern the convention.

## The seven axioms

  A0 Difference        A4 Process
  A1 Care              A5 Accounting
  A2 Curry-Howard      A6 Self-Application
  A3 Material Basis

Read `docs/axioms.md` for the canonical statement of each.
Read `theories/` for the eight theories that ground them.

## Read first (in order)

1. `README.md` — one-page manifest
2. `docs/axioms.md` — seven axioms
3. `theories/README.md` — eight theories
4. `math/<latest-packet>/decision.md` — most recent decision

Resolve the latest packet with:

  git log --oneline math/*/decision.md | head -1

## How to operate

You are a function over:

  S = (chat_history, files_read, files_written, mode, role)

Your trace is your proof term. Your type-checker is
`sh math-coding verify`. Your meta-checker is
`sh math-coding probe`.

### Mode (set in .mathrc, default standard)

  skip      no record
  light     commit message only
  standard  full 5-file packet
  strict    packet + theory link

### Role (default developer)

  developer / designer / product-manager / researcher / tech-writer

### Five files per packet (standard or strict)

  packet.yaml       manifest, lifecycle, applications[]
  decision.md       proposition (thesis / antithesis / synthesis)
  task.md           intent (problem / outcome / constraints)
  assumptions.yaml  epistemic context (5 markers)
  refinement.md     state / operation / invariant / test / runtime

### Five epistemic markers (assumptions.yaml)

  fact        B(P) ≥ 0.95
  hypothesis  0.5 < B(P) < 0.95
  judgment    B(P) ∈ {0, 1}
  unknown     B(P) = 0
  proven      end-to-end verified (axiom A6)

### Six lifecycle states (packet.yaml)

  sketch → working → verified → deprecated → archived
                                            ↑
                                            superseded

Forbidden: `sketch → verified`.

### Five verdict outcomes

  VERIFIED
  NEEDS_REVISION
  UNVERIFIABLE:TOOL_MISSING
  UNVERIFIABLE:DEFERRED
  UNVERIFIABLE:OUT_OF_SCOPE

## Writing good packets (axiom A4 + axiom A5)

A packet is the proof of your proposition. The five files
are the proof term. The verifier is the type-check. axiom A5
requires that every claim is marked with its epistemic
status. axiom A4 forbids `sketch → verified`.

A good packet is **specific**, **falsifiable**, and
**honest**.

### Good `decision.md:thesis`

A good thesis is:

  - **specific**: not "improve performance" but "reduce
    latency by 30%"
  - **falsifiable**: it can be wrong
  - **one sentence**: avoid "and"
  - **concrete**: numbers, names, paths

Good: "Cache entries expire after 60 seconds, not at user
request." Bad: "Cache is fast."

### Good `decision.md:antithesis`

A good antithesis is the **strongest objection** to the
thesis. It is not a strawman; it is the reason a thoughtful
reviewer might reject the packet.

Good: "Users may need manual invalidation; fixed TTL forces
them to wait 60 seconds." Bad: "What if we want to be
faster?"

### Good `decision.md:synthesis`

A good synthesis resolves the thesis + antithesis. It is
not "we chose this"; it is **how** the choice was made.

Good: "TTL is fixed at 60s; manual invalidation is a separate
endpoint (`--cache-invalidate`). The two paths are
independent." Bad: "We chose TTL."

### Good `assumptions.yaml`

Each assumption has:
  - **id**: A1, A2, ...
  - **statement**: one sentence
  - **status**: user-confirmed | agent-inferred | open
  - **epistemology**: fact | hypothesis | judgment | unknown |
    proven
  - **evidence**: one line, or `open` for unknown

Good:

```yaml
- id: A1
  statement: "60s is acceptable for this endpoint"
  status: user-confirmed
  epistemology: fact
  confidence: 0.95
  evidence: "SLA allows 60s for /cache"
```

Bad:

```yaml
- id: A1
  statement: "cache works"
  status: agent-inferred
  epistemology: hypothesis
  confidence: 0.5
```

### Good `refinement.md`

A good refinement is **operational**:

  - State: pre/post (specific)
  - Operation: what the agent or developer does
  - Mapping: spec state → impl state
  - Invariant: what stays true (mathematically)
  - Test: how to verify (concretely)

Good:

```markdown
State:
  pre:  cache miss (no entry for key)
  post: cache hit (entry exists, age < 60s)
Operation:
  On read, check entry timestamp. If age > 60s, refresh
  from upstream.
Mapping:
  spec: cache hit returns entry within 60s of last refresh
  impl: dict[key] returns entry if (now - ts) < 60s
Invariant:
  Cache entries never served beyond TTL.
Test:
  Insert entry with ts = now - 61s. Read. Expect upstream fetch.
```

### Lifecycle discipline

Move the lifecycle as the work progresses:

  draft     →  packet created via `sh math-coding create`
  sketch    →  first commit with code
  working   →  code committed, tests present
  verified  →  tests pass, axiom A6 holds for this packet

**Never** move `sketch → verified` directly. axiom A4
forbids it; `verify.sh` enforces it.

### Supersession

When the proposition itself changes, do not edit the old
packet. Create a new one:

```bash
sh math-coding create cache-ttl-v2 --from spec.yaml
```

In `cache-ttl-v2/packet.yaml`:

```yaml
supersession: math/cache-ttl/
```

The old packet's lifecycle becomes `superseded`. The new
packet becomes the source of truth.

See `math/packet-lifecycle/` for the full discipline.

## Commands

  sh math-coding init <name>     scaffold a 5-file packet (template)
  sh math-coding create <name>   create a packet from spec (planned)
  sh math-coding verify          structural check
  sh math-coding drift-check     applications[] SHA vs HEAD
  sh math-coding probe           axiom A6 self-application
  sh math-coding install <path>  install into a project
  sh math-coding upgrade <path>  upgrade existing install
  sh math-coding uninstall <path>

## Modes of operation

When the user asks for a non-trivial change, open a packet
with `sh math-coding init <name>`, fill the five files, and
commit. For typos and doc fixes, commit directly.

When the user asks about an axiom, cite `math/<NN-axiom>/`
and `theories/<theory>.md`.

When the user asks about the convention's own state, run
`sh math-coding probe`. If it returns 0, axiom A6 holds.