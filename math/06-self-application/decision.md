# 06-self-application

## Thesis

The convention applies to itself. Every axiom above is
realised as a packet under `math/`. The verifier that
checks those packets is itself the subject of a packet.
The probe that proves axiom Self-Application holds is
axiom Self-Application made operational.

Formally:

```
A6.  ∀ packet P ∈ math/* :
        ∀ axiom A_i (i ∈ {0,..,5}) :
          P satisfies A_i
```

axiom Self-Application is the closing of the loop. The
seven axioms are seven packets. The `core/` scripts are
themselves subjects of packets. The verifier exit-code is
itself a witness in `applications[]`.

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
that the axioms are coherent. axiom Self-Application is
more than CI. It is the convention observing its own
structure.

## Synthesis

axiom Self-Application closes the loop. The proof
obligation is

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

Each check is a predicate (axiom Process). The conjunction
of the six predicates is axiom Self-Application. The probe
evaluates the conjunction. If all six hold, exit 0.

The proof of axiom Self-Application is axiom
Self-Application itself. The script that proves axiom
Self-Application is a script written under axiom
Self-Application (axiom Curry-Howard: a script is a
proof term; axiom Process: the script's lifecycle is
verified because the probe runs; axiom Accounting: the
probe's exit code is the witness).

## What this means in practice

When you run `sh math-coding probe`, the convention runs
against itself. The seven axiom packets are the test
fixtures. The probe is the test runner. The exit code is
the verdict.

If you change `core/self/probe.sh` and break axiom
Self-Application, the probe exits non-zero. The convention
tells you. You fix the probe. axiom Self-Application
holds again.

If you change a theory file and the theory drifts from
what axiom packets cite, the probe exits non-zero. The
convention tells you. You align the theory with the packet.

The convention is not a static document. It is a system
that observes itself.

## Surface impact

touches: the six checks in `core/self/probe.sh`:
  [1/6] 5 files per packet (axiom Curry-Howard)
  [2/6] seven axioms in docs/axioms.md (axiom Process)
  [3/6] eight theories in theories/ (axiom Process)
  [4/6] verify.sh exit 0 (axiom Curry-Howard)
  [5/6] drift-check.sh exit 0 (axiom Accounting)
  [6/6] axiom dependency chain closed (axiom Process)

## Proof

The proof is the probe itself. `sh core/self/probe.sh`
exits 0 ⟺ the convention's own packets satisfy the
structure their verifier demands, the axioms in
docs/axioms.md cohere with the theories in theories/,
the core/ scripts run on a minimal POSIX shell, the
applications[] SHA witnesses resolve to real commits.

The proof of axiom Self-Application is axiom
Self-Application itself.