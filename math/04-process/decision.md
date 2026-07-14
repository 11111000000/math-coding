# 04-process

## Thesis

Process precedes code. The packet is written before the
implementation. The lifecycle of a packet is finite and
ordered.

## Antithesis

A process that begins with code cannot record intent. A
lifecycle without states is a black hole — packets appear
mature, never ripen, never retire.

## Synthesis

A4 fixes the temporal discipline: think-before-do, then
the six-state FSM `sketch → working → verified → deprecated
→ archived` with parallel `superseded`. A packet may not
skip states. A verified packet must carry a SHA witness.

## Surface impact

touches: lifecycle FSM, FSM transition discipline [FROZEN]

## Proof

axiom A2 (Curry-Howard) explains why a sketch is not a
proof. axiom A5 (Accounting) explains why verified carries
a SHA. axiom A6 verifies that no packet skips states.