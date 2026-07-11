# Refinement: theory-predicate

## State

- **pre**: math-coding claims to be grounded in math, but
  core/theories/predicate.md is abstract and doesn't show how
  math-coding uses it
- **post**: math-coding's predicate theory is concretely
  applied to lifecycle, structure check, and recursive
  observability

## Operation

- This packet documents the application of Predicate theory
  to math-coding
- It does NOT modify core/theories/predicate.md (OS file)
- It uses core/theories/predicate.md as a reference

## Invariant

- All 4 packets in math/ have 5 files each
- This packet's 5 assumptions all have evidence
- Every assertion in math-coding's invariants is now
  demonstrably a predicate

## Convention axes affected

- **Mathematics grounding (refinement.md §13):** this packet
  is the first demonstration that theory-to-application works.
  Future theory packets (FSM, LTL, etc.) follow this pattern.

## Mapping: theory → application

| Predicate theory concept | math-coding application |
|--------------------------|---------------------------|
| Predicate I: S → B | Lifecycle predicate: S = packet states, I = "packet is verified" |
| State space S | Packet state (lifecycle, file existence, decision-recursive) |
| Invariant | Recursive observability: "every packet in math/ verifiable" |
| Satisfaction check | Structural verifier (file_exists ∧ ...) |
| Counterexample | NEEDS_REVISION verdict |
| Cannot decide | UNVERIFIABLE:* verdict |

## Test obligation

- This packet documents a single mathematical pattern
  (predicate applied to convention)
- Future packets can copy this pattern for FSM, LTL, etc.

## Runtime check

- None required yet (informal application of theory)
