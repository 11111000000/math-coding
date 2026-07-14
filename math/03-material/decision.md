# 03-material

## Thesis

The convention lives in plain text, in git, and runs on a
POSIX shell. No other substrate is required.

## Antithesis

A convention that depends on a language, framework, IDE,
or vendor outlives its usefulness only as long as that
substrate survives. It cannot outlive the substrate.

## Synthesis

A3 fixes the material basis of math-coding: plain-text
artifacts, append-only ledger (git), and POSIX-portable
executables. The 5-file packet is plain text. The verifier
is POSIX shell. History is git.

## Surface impact

touches: file formats, runtime [FROZEN]

## Proof

All core/ scripts run on a minimal POSIX environment
(busybox, dash, ash). No Python, no JVM, no Node.