# references/lifecycle.md

The lifecycle FSM. Load this when the agent changes a
packet's lifecycle (sketch → working → verified) or asks
which state to use.

## Six states

| State | Meaning | When to use |
|-------|---------|-------------|
| sketch | packet created, content placeholder | right after `sh math-coding init` or `create` |
| working | content filled, code committed, but axiom A6 not yet proven for this packet | first commit with code |
| verified | axiom A6 holds for this packet; at least one SHA in `applications[]` | after the test pass |
| deprecated | superseded by another packet but still referenced | during transition period |
| superseded | replaced by another packet; `supersession:` block names the successor | after the new packet is established |
| archived | terminal; no references | when nothing depends on this packet |

## Forbidden

`sketch → verified`. The proposition has never been elaborated
(working); it cannot be proven (verified). Run axiom A4
strictly: every transition is a commit; every commit is a
SHA; every SHA is in `applications[]`.

## How to transition

1. **sketch → working**: fill in the five files with
   content. First commit with code.
2. **working → verified**: ensure axiom A6 holds for this
   packet (test passes). Add the first SHA to
   `applications[]`. Set `lifecycle: verified`.
3. **verified → deprecated**: when another packet supersedes
   this one, set `lifecycle: deprecated` and add
   `supersession: math/<newer>/`.
4. **deprecated → superseded**: when the newer packet is
   established, set `lifecycle: superseded`.
5. **superseded → archived**: when nothing references this
   packet, set `lifecycle: archived`.

## When to supersession vs amend

- **Amend** (add SHA to `applications[]`): the proposition
  is unchanged; the evidence is richer. Use for typo
  fixes, additional tests, refactors.
- **Supersession** (create a new packet with `supersession:`
  in the old one): the proposition itself changes.

The boundary is sharp: amendment extends evidence;
supersession replaces the claim.