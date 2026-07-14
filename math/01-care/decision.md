# 01-care

This packet realises [[docs/axioms.md#a1-care-motivational|axiom Care]].

## Thesis

A developer shipping a 3 AM fix to a production outage cares
whether the fix works the first time. A convention that does
not record that fix loses the fix at the next handoff.

The opposite of care is "looks fine". A developer who ships
"looks fine" writes code that passes the type-checker, has
green tests, and reads correctly on review — and breaks the
first time a user does something unexpected. Care is what
distinguishes the developer who asks "what does this code
do when the input is null?" from the developer who does not.

A1 names care as the motivation of convention. Without care,
no amount of structure helps. With care, even loose structure
works because the developer who writes the structure also
checks that it works.

## Antithesis

Without care, a convention is ceremony. Agents and humans
adopt it superficially, and drift grows in silence. The
verifier passes; the code does nothing useful. The five
files are filled with placeholder text. The SHA witness
points to a commit that contradicts the proposition.

Some agents operate without care — they optimise for
plausibility, not for truth. Some humans operate without
care — they optimise for shipping, not for correctness. A
convention that does not name care as load-bearing will be
captured by these agents and humans.

## Synthesis

A1 names the motivation behind axiom Difference. Difference
creates the gap. Care is what makes closing the gap
worthwhile. Without A1, axiom Difference would describe a
phenomenon without giving anyone a reason to do anything
about it.

Axiom Accounting operationalizes care as five epistemic
markers. The agent or developer who marks a hypothesis as
`fact` without evidence betrays A1. The agent or developer
who marks `unknown` honestly enacts A1. The five markers
are not bureaucracy. They are the discipline of care.

## A worked example

A junior developer is asked to add a cache. The naive
approach writes a hash table and calls it done. A1, applied:

  decision.md:thesis:
    "Cache entries must expire after 60 seconds.
     Manual invalidation must be a separate endpoint."

  task.md:problem:
    "Without TTL, stale data is served indefinitely after
     upstream changes."

  assumptions.yaml:
    - A1: "60s is acceptable for this endpoint" — user-confirmed
    - A2: "Upstream supports ETag-based refresh" — hypothesis

  refinement.md:invariant:
    "Cache entries never served beyond TTL."

The proposition is recorded before the code. The code
follows the proposition. If the proposition is wrong, the
code is wrong — but the convention catches that. If the code
is wrong, the tests catch that. Care, made operational.

## A second worked example: 3 AM fix

A developer is paged at 3 AM. Production is down. The fix
is small — one function, one return value. The naive move
is to commit the fix and roll back if it breaks. A1, applied:

  decision.md:thesis:
    "A 3 AM fix must work the first time because the cost of
     a second deploy during an outage is the outage itself."

  task.md:problem:
    "Rollbacks during outages cause additional load and risk.
     The fix must land and stay landed."

  assumptions.yaml:
    - A1: "the fix's effect is local to one function" — fact (verified by reading)
    - A2: "no caller depends on the old broken behaviour" — hypothesis (needs testing)

  refinement.md:invariant:
    "the fix is no-op for inputs that were already correct"

The packet forces the developer to state the assumption
"no caller depends on the old behaviour" — and to mark it
as `hypothesis`, not `fact`. The next reviewer can see the
reasoning. If the assumption is wrong, the bug returns at
4 AM, but the convention tells the next developer what was
assumed and why. Care, written down.

## Surface impact

touches: 5 epistemic markers (assumptions.yaml:epistemology),
SHA witness (packet.yaml:applications[].sha), 5 verdict
outcomes (verifier stdout)

## Proof

axiom Accounting operationalizes care: every assumption
carries an epistemic marker, every change carries a SHA
witness, every drift carries a verdict. The evidence: this
packet itself marks every assumption with an epistemic
marker; the convention's `core/check/verify.sh` rejects
markers outside the five-marker set.