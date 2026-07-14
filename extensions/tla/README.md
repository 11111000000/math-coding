# extensions/tla/

This directory extends math-coding v0.854 with TLA+
substrate support. It is **optional** — the convention works
without it.

## When to use TLA+

TLA+ is appropriate when the packet's specification
includes:

- **concurrency** (multiple actors, locks, channels)
- **distributed systems** (consensus, replication, timeouts)
- **safety-critical protocols** (state machines with
  liveness requirements)

If the packet is a single-threaded CLI command, TLA+ is
overkill. Use plain text only.

## When NOT to use TLA+

- One-shot scripts (no concurrency to model)
- Pure functions (no state)
- Standard CRUD (no distributed state)

## How to enable

1. Install TLA+ tools:
   - `tla2tools.jar` (SANY, TLC)
   - Optional: TLAPS (TLA+ Proof System)

2. Add TLA+ to the packet:

   ```
   math/my-packet/
   ├── packet.yaml       # substrate: tla
   ├── decision.md
   ├── task.md
   ├── assumptions.yaml
   ├── refinement.md
   └── Model.tla          # NEW
   ```

3. The convention's `core/check/verify.sh` does NOT check
   TLA+ syntax. That is the user's responsibility (run SANY).
   The convention enforces that `Model.tla` exists when
   `substrate: tla` is declared.

## Minimal Model.tla example

```tla
------ MODULE cache_ttl ------
EXTENDS Naturals, TLC

VARIABLES cache, clock

TypeOK == cache \in [keys -> [value: Data, ts: Nat]]
         /\ clock \in Nat

Init == /\ cache = [k \in {} |-> <<>>]
        /\ clock = 0

Tick == /\ clock' = clock + 1
        /\ UNCHANGED cache

Read(k) == /\ cache[k].ts + 60 > clock
          /\ UNCHANGED <<cache, clock>>

Expire(k) == /\ cache[k].ts + 60 <= clock
            /\ cache' = [cache EXCEPT ![k] = @]
            /\ UNCHANGED clock

Next == \E k \in DOMAIN cache: Read(k) \/ Expire(k)

Spec == Init /\ [][Next]_<<cache, clock>>

THEOREM Correctness == Spec => []TypeOK
=============================
\* Modification History
\* Last modified Wed Jul 16 12:00:00 PDT 2026
\* Created Wed Jul 16 12:00:00 PDT 2026
\* by math-coding
```

## Verify with TLC

```
$ tlc -config cache_ttl.cfg cache_ttl.tla
```

`cache_ttl.cfg`:

```
SPECIFICATION Spec
CHECK_DEADLOCK FALSE
```

## How it fits with axiom Self-Application

When a packet declares `substrate: tla` and has `Model.tla`,
the convention's `core/self/probe.sh` does NOT run TLC
(that requires Java). But the convention can detect
the presence of `Model.tla` and require the user to run
TLC separately. axiom Self-Application does not depend on
TLA+ being installed — the convention works without it.

## See also

- `extensions/obsidian.md` — Obsidian support (default)
- `extensions/agents/opencode/SKILL.md` — AI agent skill