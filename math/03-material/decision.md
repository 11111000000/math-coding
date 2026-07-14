# 03-material

## Thesis

The convention lives in plain text, in git, and runs on a
POSIX shell. No other substrate is required.

Three pillars:

  plain text — every artifact is a `.md`, `.yaml`, or `.sh`
  file. No binary blobs. No JSON-with-comments. No XML.
  Anyone with `cat` and an editor can read the convention.

  git — every change carries a SHA. History is
  append-only. Cloning the repository recreates the entire
  history on a new machine. Branches, tags, and reflog are
  all available without external services.

  POSIX — every script in `core/` runs on `dash`, `bash`,
  or `busybox sh`. No `bash` extensions. No Python. No JVM.
  No Node. A minimal Linux install with `git` and `sh` is
  sufficient.

These three pillars are independent but mutually
reinforcing. Plain text is readable across decades. Git
preserves the ledger across decades. POSIX runs across
decades.

## Antithesis

A convention that depends on a language, framework, IDE,
or vendor outlives its usefulness only as long as that
substrate survives.

A convention that depends on Python 3.12 dies when the
project moves to Python 3.13 and the dependency changes.
A convention that depends on a specific JSON library dies
when the library is deprecated. A convention that depends
on GitHub Actions dies when the project moves to GitLab.

The history of software is a graveyard of conventions
that depended on a single substrate. The cure is not to
find the right substrate. The cure is to depend on
substrates that are older than the convention itself.

Plain text (1960s), git (2005), POSIX (1988). These three
pillars are older than most projects that will adopt
math-coding. They will outlive the convention.

## Synthesis

A3 fixes the material basis of math-coding:

  packet.yaml      — plain text
  decision.md      — plain text
  task.md          — plain text
  assumptions.yaml — plain text (yaml subset)
  refinement.md    — plain text
  theories/*.md    — plain text
  core/*.sh        — POSIX shell
  core/ops/*.sh    — POSIX shell
  LICENSE          — plain text
  AGENTS.md        — plain text
  README.md        — plain text
  .git/            — git
  .gitignore       — plain text
  math-coding      — POSIX shell

Every file is one of: `.md`, `.yaml`, `.sh`. The convention
itself is a git repository. The history is git's history.

## Surface impact

touches: file formats, runtime, history [FROZEN]

## Proof

All `core/*.sh` scripts run on a minimal POSIX environment.
Verified by inspection: no `bash` extensions, no Python, no
JVM, no Node. `dash` is sufficient.

History is preserved by git. `git clone` on a fresh machine
recreates the entire repository from the network.

The five files of every packet are plain text. `cat`, `grep`,
`awk`, `sed` — all standard POSIX utilities — can read them.