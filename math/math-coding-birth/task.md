# math-coding birth

## Problem

Replace vibe-coding with math-coding across all coding
agents. The convention must work without external dependencies,
without network access, and must describe itself through its
own rules (the fractal property, A4). It must be adoptable
by an agent that reads one short file. It must be self-
consistent at every commit: the repository at any commit
is usable without referring to any later commit.

## Desired outcome

A repository where every key decision about the convention
itself is a packet. Every packet has the same fixed shape.
An agent opening a new packet can read one short file and
know what to do. After each commit, the repository at that
commit is self-consistent. After 100 commits, the convention
still applies to itself.

## Constraints

- Plain text + git only.
- No external tools beyond POSIX sh, awk, grep, sed, find.
- Every packet has exactly 5 files (no more, no less).
- Each assumption has a status marker, an epistemology
  marker, a confidence value, and evidence.
- The first commit is self-consistent.
