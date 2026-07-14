# Refinement: 04-process

## State

- pre: packets may sit forever in `sketch` or `working`,
  drifting toward claimed correctness without witness.
- post: every packet moves through six states in order,
  each transition recorded as a git commit.

## Operation

A packet transitions through six states:
  sketch → working → verified → deprecated → archived
                              ↑                ↓
                              └── superseded ←──┘

Forbidden: `sketch → verified`.

## Mapping

| state | entry condition | exit condition |
|-------|-----------------|-----------------|
| sketch | packet created (init-packet.sh) | proposition stated (decision.md) |
| working | proposition + first commit | code committed |
| verified | axiom A6 returns 0 | superseded OR deprecated |
| deprecated | superseded by another packet | archived |
| archived | terminal | none |
| superseded | replaced by newer packet | archived |

## Invariant preservation

- No packet may carry `lifecycle: verified` without a
  non-empty `applications:` block.

## Test obligation

- axiom A6 — verifier rejects `verified` without witness.

## Runtime check

None — FSM transitions are commit-time decisions.