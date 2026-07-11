# core-as-packet — core/ is operating-system

## Thesis

math-coding has multiple OS-level foundations that are NOT
decisions themselves: the packet schema (field types and
constraints), 11 mathematical theory docs, and the LICENSE.
These files must exist somewhere in the repository, but making
each of them a separate decision-packet would create noise:
not every file documents a decision.

## Antithesis

Treating every file as a decision-packet produces overhead.
In brownfield mode (existing project), most files are OS files
(no packet needed, per birth-пакет A3). The convention must
distinguish decision-packets (in math/) from operating-system
files (anywhere else).

## Synthesis

The `core/` directory holds two kinds of OS files:
- `packet-schema.md` — the canonical packet field schema
- `theories/*.md` — 11 mathematical theory docs

This packet authorizes those files as convention-OS. It is
itself a decision-packet (a decision about what OS files
exist) but the files it authorizes are not packets.

## What this packet commits to

- `core/packet-schema.md` is the canonical schema for
  `packet.yaml` fields (markdown table).
- `core/theories/*.md` are 11 mathematical theory docs (OS).
- This packet authorizes these OS files; no future packet
  may modify them without opening a new supersession.

## What this packet does NOT commit to

- A JSON Schema variant (deferred — markdown suffices for now).
- Additional theory files beyond the 11 currently listed.
- A separate `core/`-as-packet schema (this IS the schema).
