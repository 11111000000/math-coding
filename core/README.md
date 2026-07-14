# core/

Installation payload for math-coding v0.854.

## Layout

  check/      — verification tools
    verify.sh       five-file contract, FSM enums, axioms, theories
    drift-check.sh  applications[] SHA vs git HEAD

  author/     — authoring tools
    init-packet.sh  scaffold the 5-file packet

  agent/      — agent runtime
    mathrc.sh       load ./.mathrc, set MODE/ROLE defaults

  axiom/      — axiom A6 (self-application)
    probe.sh        orchestrator: verifier + drift + axioms

  spec/       — specification documents
    packet-schema.md
    think-before-do.md
    decision-modes.md

  install/    — brownfield lifecycle
    install.sh
    upgrade.sh
    uninstall.sh

## Dispatcher

The dispatcher `math-coding` lives in the repository root.
It routes commands to the right tool:

  sh math-coding init <name>     → core/author/init-packet.sh
  sh math-coding verify           → core/check/verify.sh
  sh math-coding drift-check      → core/check/drift-check.sh
  sh math-coding probe            → core/self/probe.sh
  sh math-coding install <path>   → core/install/install.sh
  sh math-coding upgrade <path>   → core/install/upgrade.sh
  sh math-coding uninstall <path> → core/install/uninstall.sh

The dispatcher knows the path layout. The tools know their
own role. The two are decoupled.

## Invocation

Every script can be invoked directly:

  sh core/check/verify.sh
  sh core/self/probe.sh
  sh core/author/init-packet.sh foo

The dispatcher is the user-facing entry point. Direct
invocation is for tooling and tests.

## REPO_ROOT

Every script computes its own REPO_ROOT:

  REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

For `core/check/verify.sh`, that's `$(dirname "$0")/../..`
which is the repository root. The script then operates on
`$REPO_ROOT/math/`, `$REPO_ROOT/theories/`, and so on.

## No external dependencies

Every script uses only POSIX-defined utilities: `test`,
`awk`, `sed`, `grep`, `git`, `find`, `mktemp`, `printf`. No
bash, no Python, no JVM. Verified to run on `dash` and
`busybox sh`.