# core-as-packet — task

## Problem

The `core/` directory contains 12 OS files (1 schema + 11
theories). These files document the convention's foundation.
They must exist, but treating them as separate decision-packets
would create artificial decisions where no real decision exists.

## Desired outcome

A single decision-packet (`core-as-packet`) that authorizes
the existence of `core/` as convention-OS, and lists the 12 OS
files it contains. The packet itself has 5 files (standard
structure), and references the OS files it authorizes.

## Constraints

- The packet must be self-consistent at this commit.
- The 12 OS files in core/ already exist; this packet only
  authorizes them.
- No new files in core/ are added by this commit.
- The packet's `depends_on:` references `math-coding-birth` (it
  extends the seed).
