# 06-self-application

## Thesis

The convention applies to itself. Every axiom above is
realised as a packet under math/. The verifier that checks
those packets is itself the subject of a packet.

## Antithesis

A convention that cannot verify itself relies on external
authority — a maintainer, a reviewer, a runtime. That
authority can disappear; the convention then rots in
silence.

## Synthesis

A6 closes the loop. The seven axioms are seven packets.
The core/ scripts are themselves subjects of packets. The
verifier exit-code is itself a witness in applications[].

axiom A6 names this closure. `sh core/axiom/probe.sh` is
its proof: when the script returns 0, the convention has
applied itself to its own state and found itself consistent.

## Surface impact

touches: the convention's relationship with itself [FROZEN]

## Proof

`sh core/axiom/probe.sh` exits 0 ⟺ the convention's own
packets satisfy the structure their verifier demands, the
axioms in docs/axioms.md cohere with the theories in
theories/, the core/ scripts run on a minimal POSIX shell,
the applications[] SHA witnesses resolve to real commits.

The proof of A6 is A6 itself.