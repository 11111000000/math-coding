# core/

Installation payload for math-coding v0.991.

## Layout

  author/     — authoring tools
    create-packet.sh   spec → 5 files
    extract-packet.sh  reverse: 5 files → YAML spec
    apply-packet.sh    SHA-witness + lifecycle transition
    review-packet.sh   peer-review verdict
    retire-packet.sh   transition to retired
    abandon-packet.sh  transition draft → abandoned
    archive-packet.sh  move retired packet to math/archived/
    config.sh          interactive .mathrc editor
    stable.sh          mark packet stable

  check/      — verification tools
    verify.sh       packet contract, lifecycle, axioms, theories
    drift-check.sh  applications[] SHA vs git HEAD

  agent/      — agent runtime
    mathrc.sh       load ./.mathrc, set MODE/ROLE defaults

  self/       — axiom Self-Application (meta)
    probe.sh        orchestrator: verifier + drift + axioms

  spec/       — specification documents
    packet-schema.md
    think-before-do.md
    decision-modes.md

  install/    — brownfield lifecycle
    install.sh
    upgrade.sh
    uninstall.sh
    install-skill.sh
    install-smoke-test.sh

## Dispatcher

The dispatcher `math-coding` lives in the repository root.
It routes commands to the right tool:

  sh math-coding create <name> --from <spec>
                       → core/author/create-packet.sh
  sh math-coding apply <name>
                       → core/author/apply-packet.sh
  sh math-coding review <name> ...
                       → core/author/review-packet.sh
  sh math-coding retire <name> ...
                       → core/author/retire-packet.sh
  sh math-coding abandon <name>
                       → core/author/abandon-packet.sh
  sh math-coding archive <name> ...
                       → core/author/archive-packet.sh
  sh math-coding lifecycle <name> <state>
                       → applies one of the above
  sh math-coding stable <name>
                       → core/author/stable.sh
  sh math-coding config
                       → core/author/config.sh
  sh math-coding verify
                       → core/check/verify.sh
  sh math-coding drift-check
                       → core/check/drift-check.sh
  sh math-coding probe
                       → core/self/probe.sh
  sh math-coding install <path>
                       → core/install/install.sh
  sh math-coding upgrade <path>
                       → core/install/upgrade.sh
  sh math-coding uninstall <path>
                       → core/install/uninstall.sh
  sh math-coding install-skill
                       → core/install/install-skill.sh

The dispatcher knows the path layout. The tools know their
own role. The two are decoupled.

## Invocation

Every script can be invoked directly:

  sh core/check/verify.sh
  sh core/self/probe.sh
  sh core/author/create-packet.sh my-pkt --from spec.yaml

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
