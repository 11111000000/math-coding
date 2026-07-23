# decision-modes (math-coding v0.992)

Three modes govern how much ceremony a change requires.

## light

A `light` change is a typo, a doc fix, or a one-line
behaviour tweak. It is recorded as a commit message.

  Required:
    - commit message with one-line rationale

  Forbidden:
    - any change to math/, core/theories/, docs/, or core/
    - any change to public surface

## standard

A `standard` change is a new feature, a new packet, a
substantive refactor. It is recorded as a 5-file packet.

  Required:
    - 5 files: packet.yaml, decision.md, task.md,
      assumptions.yaml, refinement.md
    - lifecycle transitions: sketch → working → verified
    - applications[] SHA when entering verified

  Forbidden:
    - skipping `working`
    - verified without applications[]

## strict

A `strict` change is architectural: a new axiom, a new
theory, a new convention rule. It is recorded as a packet
plus a theory link.

  Required:
    - all standard-mode requirements
    - reference to a theory in core/theories/
    - reference to an axiom in core/spec/axioms.md
    - surface impact (if the change touches a public contract)

  Forbidden:
    - introducing a new axiom without an axiom packet
    - removing an axiom without a supersession packet

## Default by role

  developer          →  standard
  designer           →  light
  product-manager    →  light
  researcher         →  strict
  tech-writer        →  skip (or light)

## Choosing the mode

The mode is set by the pressure in `decision.md`:

  bug       — usually standard (fix a known defect)
  feature   — usually standard (new capability)
  debt      — usually standard (clean up existing code)
  ops       — usually light (configuration, tooling)
  arch      — usually strict (architecture change)

A `light` change that touches math/, core/theories/, docs/, or
core/ is automatically `standard`. The verifier rejects it
otherwise.

## Mode transitions

A change may escalate between modes:

  light → standard :  if the change requires packet updates
  light → strict   :  if the change touches axioms
  standard → strict :  if the change introduces a new theory

A change may not de-escalate. A `strict` change may not be
re-classified as `light` post-hoc.