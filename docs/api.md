# API stability (math-coding v0.854)

This document defines the **stable** surface of the
convention. Changes to the stable surface require a
major-version bump (e.g. v0.854 → v1.0).

## Stable scripts

These scripts are part of the public surface. They can
be invoked from CI, brownfield scripts, or shell pipelines
without changes within a major version.

| Script | Purpose |
|--------|---------|
| `core/author/init-packet.sh` | scaffold 5-file packet (template) |
| `core/author/create-packet.sh` | spec-driven packet creation (one call) |
| `core/author/extract-packet.sh` | reverse: 5 files → YAML spec |
| `core/check/verify.sh` | structural + axioms + theories check |
| `core/check/drift-check.sh` | applications[] SHA vs HEAD |
| `core/agent/mathrc.sh` | load ./.mathrc |
| `core/self/probe.sh` | axiom Self-Application check |
| `core/install/install.sh` | brownfield install |
| `core/install/upgrade.sh` | brownfield upgrade |
| `core/install/uninstall.sh` | brownfield uninstall |
| `math-coding` (root) | dispatcher |

## Stable commands

The dispatcher `math-coding` exposes these commands:

| Command | Behavior |
|---------|----------|
| `init <name>` | scaffold a 5-file packet |
| `create <name> --from <spec>` | create from spec |
| `extract <name>` | emit YAML spec to stdout |
| `verify` | run verify.sh |
| `drift-check` | run drift-check.sh |
| `probe` | run probe.sh (axiom Self-Application) |
| `install <path>` | install to path |
| `upgrade <path>` | upgrade install at path |
| `uninstall <path>` | uninstall from path |
| `help` | show usage |

Within a major version, these commands and their flags are
stable. Renaming a command is a breaking change.

## Stable packet format

The 5-file packet format is stable:

- `packet.yaml` — manifest
- `decision.md` — proposition
- `task.md` — intent
- `assumptions.yaml` — epistemic context
- `refinement.md` — state/operation/mapping/invariant/test

Adding files is a **non-breaking** change (extension).
Renaming or removing files is a **breaking** change.

## Stable applications[] fields

Each entry in `packet.yaml:applications[]` has these
fields:

- `sha` — git commit SHA
- `by` — author name
- `date` — ISO 8601 date
- `files` — list of paths changed
- `pressure` — bug | feature | debt | ops

Adding fields is non-breaking. Removing fields is breaking.

## Stable epistemic markers

The five epistemic markers are stable:

- `fact`, `hypothesis`, `judgment`, `unknown`, `proven`

Adding new markers is a **major** change (extends axiom
Accounting). Removing existing markers is breaking.

## Deprecation policy

- A feature in v0.x is **deprecated** when marked in
  `CHANGELOG.md` and in the relevant file's header comment.
- A deprecated feature is **removed** in the next minor
  version (v0.(x+10)).
- Deprecation warnings appear in script output during the
  deprecation window.

## Versioning

Versions follow the φ-recurrence:

```
v_{n+1} = v_n + (1 - v_n) * 0.618
```

The convention approaches but never reaches 1.0. v1.0 would
require a major-version decision (explicit, not automatic).

## See also

- `AGENTS.md` — runtime hint for AI agents
- `CONTRIBUTING.md` — how to contribute
- `CHANGELOG.md` — version history