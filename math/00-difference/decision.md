# 00-difference

## Thesis

A proposition is a claim in language. An implementation is
a sequence of executable symbols. They are not the same
thing. Without this gap, math-coding has nothing to bridge.

Consider a junior developer who writes:

```python
def add(a, b):
    return a + b
```

and commits it without a test, without a comment, without
a story. The implementation exists. The proposition — what
this code is supposed to mean, in which context it is correct,
what it does not cover — does not. Six months later, someone
adds a string to the call. The result is wrong. Nobody knew
it was wrong, because the proposition was never recorded.

A0 fixes this: the proposition is a separate object from
the code. It lives in `decision.md`. It has a `task.md` that
states the intent. It has `assumptions.yaml` that names what
is taken for granted. It has `refinement.md` that maps the
proposition to the implementation. The code is the last step,
not the first.

## Antithesis

If proposition equals implementation, no convention is needed.
Code that explains itself has no decision to record.

But code does not explain itself. A function `add(a, b)`
is correct in arithmetic and wrong in string concatenation.
The implementation carries no hint which one. The proposition
must come from somewhere. Without a separate place for it,
the developer guesses, the reviewer guesses, the user
discovers.

Some methods try to recover the proposition from the code —
docstrings, type annotations, formal specifications embedded
in the implementation. Each of these is a partial answer
that re-introduces the gap by another name. A0 says: do not
hide the gap. Name it.

## Synthesis

A0 grounds math-coding on difference. Each axiom that
follows exists because some proposition differs from some
implementation. axiom A2 (Curry-Howard) names this bridge.
axiom A6 (Self-Application) verifies that the bridge holds
when the convention applies it to itself.

The five-file packet is the practical form of A0:

  packet.yaml      — the manifest, the type signature
  decision.md      — the proposition, the claim
  task.md          — the intent, the goal
  assumptions.yaml — the context Γ, what we take for granted
  refinement.md    — the elaboration, how the claim unfolds

Without A0, the five files collapse to one. With A0, each
file has a job.

## Surface impact

touches: convention's foundation [FROZEN]

## Proof

axiom A2 (Curry-Howard) instantiates the bridge. axiom A6
(Self-Application) verifies that the convention's own packets
satisfy the structure their verifier demands.