# 06-self-application

## Thesis

The convention applies to itself. Every axiom above is
realised as a packet under `math/`. The verifier that
checks those packets is itself the subject of a packet.
The probe that proves axiom A6 holds is axiom A6 made
operational.

Formally:

```
A6.  ∀ packet P ∈ math/* :
        ∀ axiom A_i (i ∈ {0,..,5}) :
          P satisfies A_i
```

axiom A6 is the closing of the loop. The seven axioms are
seven packets. The `core/` scripts are themselves subjects
of packets. The verifier exit-code is itself a witness in
`applications[]`.

`sh core/self/probe.sh` is the proof: when the script
returns 0, the convention has applied itself to its own
state and found itself consistent.

## Antithesis

A convention that cannot verify itself relies on external
authority — a maintainer, a reviewer, a runtime. That
authority can disappear; the convention then rots in
silence.

Many conventions are exactly this. They have a README that
asserts "we follow these principles" and no script that
checks whether the principles are followed. The principles
are held in the maintainer's head; when the maintainer
leaves, the principles leave.

Some conventions try to test themselves via a CI pipeline
that runs after every commit. This is necessary but not
sufficient. CI can check that tests pass; it cannot check
that the axioms are coherent. axiom A6 is more than CI. It
is the convention observing its own structure.

## Synthesis

axiom A6 closes the loop. The proof obligation is

```
sh core/self/probe.sh  →  exit 0
```

The probe runs six checks:

  [1/6]  every math/<pkt>/ has five files
  [2/6]  docs/axioms.md lists seven axioms
  [3/6]  theories/ contains eight theories
  [4/6]  core/check/verify.sh exits 0
  [5/6]  core/check/drift-check.sh detects no drift
  [6/6]  axiom packets form a dependency chain

Each check is a predicate (axiom A4). The conjunction of the
six predicates is axiom A6. The probe evaluates the
conjunction. If all six hold, exit 0.

The proof of A6 is A6 itself. The script that proves A6 is
a script written under A6 (axiom A2: a script is a proof
term; axiom A4: the script's lifecycle is verified because
the probe runs; axiom A5: the probe's exit code is the
witness).

## What this means in practice

When you run `sh math-coding probe`, the convention runs
against itself. The seven axiom packets are the test
fixtures. The probe is the test runner. The exit code is the
verdict.

If you change `core/axiom/probe.sh` and break axiom A6,
the probe exits non-zero. The convention tells you. You fix
the probe. axiom A6 holds again.

If you change a theory file and the theory drifts from
what axiom packets cite, the probe exits non-zero. The
convention tells you. You align the theory with the packet.

The convention is not a static document. It is a system
that observes itself.

## Surface impact

touches: the convention's relationship with itself [FROZEN]

## Proof

`sh core/self/probe.sh` exits 0 ⟺ the convention's own
packets satisfy the structure their verifier demands, the
axioms in docs/axioms.md cohere with the theories in
theories/, the core/ scripts run on a minimal POSIX shell,
the applications[] SHA witnesses resolve to real commits.

The proof of A6 is A6 itself.