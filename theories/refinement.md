# Refinement (axiom Process)

A refinement is a relation:

```
R ⊆ S_impl × S_spec
```

such that every implementation behaviour has a matching
(possibly stuttering) specification behaviour:

```
S_impl ⊨ R(S_spec)
```

## math-coding instance

In math-coding, the packet is the specification; the
implementation is whatever realises the packet. The
`refinement.md` of each packet declares:

  State    : pre-state, post-state
  Operation : the action that implements the packet
  Mapping   : spec state → impl state
  Invariant : what stays true
  Test      : how to verify
  Runtime   : how to monitor

## Worked example

Consider `math/cache-ttl/`:

  decision.md (spec):
    "Cache entries expire after 60 seconds."

  refinement.md (mapping):
    State:
      pre:  cache miss (no entry)
      post: cache hit (entry exists, expires after 60s)
    Operation:
      "On read, check entry timestamp. If age > 60s, refresh
       from upstream."
    Mapping:
      spec: cache hit after 60s of inactivity
      impl: dict.get(key) returns entry if (now - ts) < 60s
    Invariant:
      "Cache entries never served beyond TTL."
    Test:
      "Insert entry with ts = now - 61s. Read. Expect upstream
       fetch."

The verifier (axiom Curry-Howard) checks that the
packet structure holds. The tests check that the refinement
mapping holds. The two are complementary.

## Why it matters

A packet without a refinement is a wish. The proposition
exists in `decision.md`; the code exists in `src/`; the
relationship between them does not exist anywhere. The
verifier cannot check the relationship because the
relationship is not stated.

axiom Process forces the relationship to be stated in
`refinement.md`. The mapping is explicit. The invariant
is explicit. The test is explicit. A reviewer can check the
mapping without running the code.

## Connection to FSM

The FSM (axiom Process FSM) describes **when** transitions
happen. The refinement describes **what** the transitions
mean. Together: when and what.

See `theories/fsm.md` for the FSM.