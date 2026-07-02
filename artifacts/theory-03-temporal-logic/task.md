# Theory 03 — Temporal Logic

## Problem

Safety properties ("nothing bad happens") are not enough.
Some properties are **liveness** ("something eventually happens")
or **until** ("P holds until Q"). The convention needs to
express these but currently has no notation for them.

## Desired outcome

A document that:
- Defines LTL operators: `[]`, `<>`, `~>`, `WF`, `SF`
- Connects each operator to a typical packet lifecycle property
- Provides example specifications in compact form
- Distinguishes safety from liveness

## Constraints

- Notation matches theory-01 and theory-02
- Examples are drawn from packet lifecycle, not abstract FSMs
- The reader can copy an LTL formula into a packet and have
  it make sense

# Adaptations

(none)