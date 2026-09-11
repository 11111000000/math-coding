# Refinement: shared-install-v0993

## State

  - pre: target repo contains `.math-coding/` with full payload (~21 files, ~7000 LoC) after `install`.
  - post: target repo contains `math/`, `.mathrc`, and a 25-line `math-coding` wrapper; payload lives at `$XDG_DATA_HOME/math-coding/<ver>/`.

## Operation

  - `core/install/install.sh` writes payload once into `$XDG_DATA_HOME/math-coding/<ver>/`, sets `current` symlink, and writes wrapper + `.mathrc` + `math/README.md` into the target project.
  - `core/install/install.sh --local` reproduces the legacy in-repo copy (CI sandbox mode).
  - The project wrapper resolves in order: `$MATH_CODING_HOME/current`, then `$XDG_DATA_HOME/math-coding/current`, then `$HOME/.local/share/math-coding/current`, then `./.math-coding/` (legacy).
  - `core/author/lifecycle.sh` replaces the seven author scripts; sub-commands: `apply`, `review`, `retire`, `abandon`, `stable`, `archive`, `amend` map to one script with internal subcommands.
  - `core/author/{extract,config}-packet.sh` are removed; `extract` is replaced by `sh math-coding extract <name>` written as a small awk pipeline, `config` is removed (handbook operation).

## Invariant preservation

  Every dispatcher exit code is unchanged: `verify` exits 0 on valid state, non-zero on bad state; `probe` exits 0 when self-application holds. The shared install does not alter the verifier's semantics.

## Test obligation

  `sh core/install/install-smoke-test.sh` exits 0. Inside it: install writes payload to shared dir, project wrapper invokes dispatcher, create scaffolds a packet, apply records witness, review approves, verify passes, probe passes, uninstall removes wrapper and project-local state.
