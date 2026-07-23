# naming-tidy-v0992

## Problem

  Packet names with version tags place the tag at the end: <slug>-v<N><N><N>.

## Desired outcome

  Every packet name follows the same convention for version-tag position. ls math/ gives a stable order; reader does not guess where version sits.

## Constraints

- proposition must remain true
- invariant must hold across all transitions
