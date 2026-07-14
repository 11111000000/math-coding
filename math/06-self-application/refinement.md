# Refinement: 06-self-application

## State

- pre: the convention exists in fragments — packets, scripts,
  theories, axioms — but no single act demonstrates their
  mutual coherence.
- post: `sh core/self/probe.sh` runs and returns 0. The
  convention has applied itself to its own state and found
  itself consistent.

## Operation

probe.sh performs these checks:

1. Every math/<pkt>/ has exactly five files.
2. Every packet.yaml declares one of the seven epistemic
   markers per assumption.
3. Every axiom packet references its predecessors in
   depends_on:.
4. docs/axioms.md lists exactly seven axioms in canonical
   order (A0, A1, A2, A3, A4, A5, A6).
5. theories/ contains the eight theories cited from the
   seven axiom packets.
6. Every application[] SHA resolves to a real commit in
   the git history.

## Mapping

| A6 obligation | probe.sh check |
|--------------|----------------|
| five files per packet | `find math -name packet.yaml \| wc -l` matches count of `*/{decision,task,assumptions,refinement}.md` |
| epistemic markers | grep assumptions.yaml for invalid markers |
| depends_on chain | topological sort; reject cycles |
| axioms doc | grep `^## A[0-9]\.` for exactly seven |
| theories present | for each theory cited in axiom packets, assert file exists |
| SHA witness | for each SHA in applications[], assert git rev-parse succeeds |

## Invariant preservation

- A6 holds across all edits that pass probe.sh.
- A6 cannot hold vacuously: probe.sh is a POSIX shell
  script that runs against the real filesystem and real
  git history.

## Test obligation

- probe.sh exit 0 = axiom A6 proven.
- probe.sh exit non-zero = drift; the verdict lists the
  first failing check.

## Runtime check

- axiom A6 itself — the convention's own runtime.