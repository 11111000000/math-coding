# naming-tidy-v0992

## Thesis

  Packet names with version tags place the tag at the end: <slug>-v<N><N><N>.

## Antithesis

  A more elaborate naming convention (kind enum, prefix-categories, axiom prefix) would catch more drift but adds ceremony that the convention does not need today. Version-position is the only inconsistency that actively confuses readers.

## Synthesis

  Minimal patch: rename the single inconsistent name (v0-991-epistemic → epistemic-v0991), add a one-line rule, add a test. No kind enum, no axiom-prefix, no bulk renames. Other inconsistencies can be addressed when they bite.
