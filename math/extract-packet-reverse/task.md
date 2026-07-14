# extract-packet-reverse

## Problem

Reading a packet's content requires parsing five files.
Cross-tool integration is hard when the convention is
expressed as a directory of files.

## Desired outcome

A single-call extractor that emits a YAML spec
representing the packet. The spec is in the same shape
as `create-packet.sh` input, enabling round-trip.

## Constraints

- POSIX shell only (axiom Material Basis).
- Output must be valid YAML that `create-packet.sh` can
  consume (round-trip).
- No information loss: every field in the 5 files must
  appear in the spec.