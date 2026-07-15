# theory-formal-statements

## Problem

The 8 theories have **visual** definitions (using Unicode
characters like ⇔, ⊆, ⟨, ⟩) but no **theorem-proof** structure.
A reader cannot see the proof without running the 16
self-tests.

## Desired outcome

Each theory has a **Theorem** block and a **Proof** block
(1-2 lines each). The convention becomes **mathematically
self-documenting**: the proof is in the theory file itself,
not just in the test output.

## Constraints

- KISS: each theorem ≤ 1 line, each proof ≤ 2 lines.
- Use **references** to existing files (axiom A2, axiom
  A4, axiom A6) — no new proofs.
- No new dependencies.
- Empirical tests still pass.