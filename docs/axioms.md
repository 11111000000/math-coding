# Seven Axioms (math-coding v0.854)

The convention is grounded on seven axioms. Each axiom
corresponds to a packet under `math/<NN-axiom>/`. Each axiom
is a subject of a packet, not merely a statement.

## A0. Difference (ontological)

A proposition differs from its implementation. Without
this gap, no convention is needed.

  Packet: math/00-difference/

## A1. Care (motivational)

A developer cares whether the code does what it claims. That
care is what makes convention useful.

  Packet: math/01-care/

## A2. Curry-Howard (structural)

A packet is a proof term. A verifier is a type-check. The
five files of a packet are the canonical projection of a
typed lambda-term.

  Packet: math/02-curry-howard/

## A3. Material Basis (substrate)

The convention lives in plain-text files, in git history,
and runs on a POSIX shell. No other substrate is required.

  Packet: math/03-material/

## A4. Process (temporal)

Process precedes code. Six-state lifecycle FSM:
`sketch → working → verified → deprecated → archived` with
parallel `superseded`. Forbidden: `sketch → verified`.

  Packet: math/04-process/

## A5. Accounting (epistemic)

Knowledge must be marked. Verdicts must be named. Changes
must be witnessed. Modes must be honest about scope.

  Five epistemic markers, five verdict outcomes, SHA witness
  via `applications[]`, supersession DAG, three modes.

  Packet: math/05-accounting/

## A6. Self-Application (meta)

The convention applies to itself. Every axiom above is
realised as a packet under `math/`. The verifier is itself
the subject of a packet.

  `sh core/self/probe.sh` exits 0 ⟺ the convention is
  internally consistent.

  Packet: math/06-self-application/

---

## Order of dependency

  A0 (ontological) → A1 (motivational) → A2 (structural) →
  A3 (substrate) → A4 (temporal) → A5 (epistemic) → A6 (meta)

Each axiom depends on the preceding axioms; each axiom is
also instantiated as a packet that the next axiom depends on.

## Reading order

For first contact, read A0 → A1 → A2 → A6. These four give
the ontological foundation (A0), the motivation (A1), the
structural bridge (A2), and the meta-discipline (A6). The
remaining axioms (A3-A5) operationalise the first four into
material basis, process, and accounting.

For implementation, read A2 → A3 → A5 → A4. These give the
structural template (A2), the substrate (A3), the accounting
instruments (A5), and the temporal discipline (A4).