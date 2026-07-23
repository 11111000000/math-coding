# Refinement: naming-tidy-v0992

## State

- pre: <state before implementation>
- post:   Every packet name follows the same convention for version-tag position. ls math/ gives a stable order; reader does not guess where version sits.

## Operation

  sh meta/naming-tidy.sh renames v0-991-epistemic and verifies no other names violate the version-suffix rule. Test fails if a name has embedded version not at end.

## Invariant preservation

  - Version tags use format -v<N><N><N> (no dots)
  - Version tag is suffix (last segment of name)
  - Axiom packets (0X-name) keep their legacy form
  - Packet names without version are unchanged

## Test obligation

  sh tests/naming-version.sh passes for all packets under math/. Names with version have suffix -v<digits>; names without version have no embedded version-like substring.
