# ADR 0003 — Plain Text and Git

## Problem

How to keep the convention portable across systems without
requiring installation of specific tools or runtimes? External
tool dependencies create friction that blocks adoption.

## Desired outcome

The convention works on any Unix-like system with sh, awk,
grep, sed, find, and git. Optional tools are recorded per-packet
in their packet.yaml so users can opt in as needed.

## Constraints

- sh, awk, grep, sed, find, git are the only required tools
- Optional tools (TLC, tsc, hypothesis, mkdocs) are documented