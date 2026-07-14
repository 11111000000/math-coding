# Refinement (A4)

A refinement is a relation

  R ⊆ S_impl × S_spec

such that every implementation behaviour has a matching
(possibly stuttering) specification behaviour:

  S_impl ⊨ R(S_spec)

In math-coding, the packet is the specification; the
implementation is whatever realises the packet. The
`refinement.md` of each packet declares:

  State    : pre-state, post-state
  Operation : the action that implements the packet
  Mapping   : spec state → impl state
  Invariant : what stays true
  Test      : how to verify
  Runtime   : how to monitor

axiom A4 fixes the lifecycle as a refinement relation
between spec-side (packet) and impl-side (code).

See math/04-process/, math/02-curry-howard/.