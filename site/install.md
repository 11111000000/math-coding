# Install math-coding

> Four paths to a working `mathc` binary. Pick the one that
> matches your environment; all four ship the same release
> artefact, identified by SHA-256.

math-coding ships as four independent install channels. Each
is the same `mathc` binary published from a single build; the
channels differ in how the binary reaches the host and how
much of the host environment the channel assumes.

## Choose your channel

| Channel | When to use | Install command |
|---|---|---|
| Release binary (POSIX) | Default. Linux (glibc **and** musl auto-detect), macOS, WSL, Git-Bash, MSYS, Cygwin. | `curl -fsSL https://github.com/11111000000/math-coding/releases/latest/download/install.sh \| sh` |
| Release binary (Windows) | Windows 10+ / Windows 11 with PowerShell 5.1+ / 7+. | `irm https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 \| iex` |
| Docker image | No sudo, no writable `~/.local/`, restricted CI runner, or you want a hermetic run. Fallback for environments where `curl \| sh` is blocked. | `docker run --rm -v "$PWD:/repo" ghcr.io/11111000000/mathc:${VERSION} validate decisions/foo.yaml` |
| Nix run | You have Nix ≥ 2.18 with flakes enabled and prefer zero-install. | `nix run github:11111000000/math-coding -- validate decisions/foo.yaml` |
| Source build | You are modifying `lib/` or `bin/`. | `nix develop .#test && dune build --root . bin/mathc.exe` |

The release binary is the recommended default for two reasons:
(a) the install script verifies the SHA-256 of the downloaded
binary against `SHA256SUMS` published on the same release,
defending against network MITM; (b) the script also installs
the per-user opencode skill in the same invocation (`--user-skill`).

## For AI agents

Two install paths exist for agent skills, mirroring the binary:

- **Per-repo**: copy `dist/adoption/opencode/SKILL.md` (from the
  release's `dist-adoption.tar.gz`) into
  `.opencode/skills/math-coding/SKILL.md` in the target repo.
  This pins a specific math-coding version for that repo's
  agent sessions.

- **Per-user**: pass `--user-skill` to `install.sh`. The skill
  lands at
  `${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/math-coding/SKILL.md`
  and applies to every opencode session on the host, across
  all repos. Re-run with `--upgrade` after a math-coding
  release.

The per-repo path is the documented production contract:
`adoption/SKILL.md:188` (the frontmatter `compatible_with:
mathc@>=X.Y.Z` field) enforces the version pin. The per-user
path is the convenience for "scaffold a new math-coding
project" — `install.sh --user-skill --upgrade` after each
release keeps the skill current.

## Verify

After any install, verify with:

```bash
mathc version
mathc self-check
mathc validate decisions/<your-first-decision>.yaml
```

`mathc version` prints the version string from the binary.
`mathc self-check` runs the kernel against the current
repository and reports pass/unknown/fail. `mathc validate`
checks a single decision file against the schema; the exit
code is 0 on accept, 1 on reject, 2 on input error.

## What the installer does on your machine

1. Detects OS / arch (`linux|darwin`, `x86_64|aarch64`).
   On Linux Git-Bash / MSYS / Cygwin shells, treats them
   as Linux POSIX and downloads the matching glibc binary;
   the native Windows host is routed to `install.ps1`
   (PowerShell).
2. On Linux, auto-detects glibc vs musl via
   `getconf GNU_LIBC_VERSION` and `ldd --version`; selects
   `mathc-linux-<arch>` or `mathc-linux-<arch>-musl` accordingly.
   Override with `--libc=glibc` or `--libc=musl`.
3. Downloads `SHA256SUMS` from the same release; refuses on
   `MC-INSTALL-CHECKSUM-MISMATCH`.
4. Idempotently appends `export PATH="$dir:$PATH"` to
   `~/.bashrc` / `~/.zshrc` / `~/.kshrc` / `~/.profile`
   (whichever is writable). Use `--no-path-update` to skip.
5. Optional `--user-skill`: also extracts
   `adoption/opencode/SKILL.md` from `dist-adoption.tar.gz`
   and writes to `${XDG_CONFIG_HOME:-${HOME}/.config}/opencode/skills/math-coding/SKILL.md`.
6. Default-on `--cosign-verify` runs `cosign verify` against
   the ghcr.io Docker image signature. Falls back to a
   warning when `cosign` is absent; use `--no-cosign-verify`
   to suppress.

## Scaffold a new project

Once `mathc` is on the PATH, the recommended adoption path for
a new project is:

```bash
cd /path/to/new-project
mathc init .                 # scaffolds decisions/, attestations/,
                              # decisions/decision.yaml, .githooks/
```

`mathc init` (decision `ux-3-init-subcommand-2026-10`):

- Creates `decisions/` and `attestations/` in the target dir.
- Writes `decisions/decision.yaml` with the active policy
  (verbatim copy of the install-tooling template, which is
  `math-coding/3.2`).
- Installs `.githooks/pre-commit` (unless `--no-install`).
- **Refuses** on `docs/arc42/`, `docs/adr/`, or `adr/`
  presence unless `--merge` is passed. The refuse message
  names the detected convention and points at
  `mathc import-adr` (below) as the brownfield path.
- Flags: `--agent` (per-platform skill placement, currently
  a no-op beyond input validation), `--from-adr` (deferred),
  `--no-install`, `--merge`.

For a project with existing MADR or adr-tools ADRs, use
`mathc import-adr` per file (decision
`ux-3-import-adr-subcommand-2026-10`):

```bash
# Single file (prints YAML to stdout)
mathc import-adr docs/adr/0001-use-postgres.md

# All MADR files (writes to decisions/<id>.yaml; reviewer
# fills in scope.paths[] before mathc validate accepts)
for f in docs/adr/*.md; do
  mathc import-adr "$f" --write
done
```

## Migrate from earlier version

Re-running `install.sh` on a host that already has `mathc`
is a no-op when the version matches (`install.sh --check`
exits 0). When the version differs, the script overwrites the
binary in place; the per-user skill is overwritten only with
`--user-skill --upgrade`.

For per-repo skills, copy the new `dist/adoption/opencode/SKILL.md`
into the project's `.opencode/skills/math-coding/SKILL.md`.
The version pin in the frontmatter is the documented source
of truth for "which release was this repo authored against".

## Sandbox notes

On NixOS, the default kernel builds via
`flake.nix` produce a `mathc` linked against
`/nix/store/<hash>-glibc-2.42`. That binary fails on hosts
whose system glibc is older than 2.42. The release.yml
pipeline builds via system opam on Ubuntu 22.04; the released
binaries link against the runner's glibc and are portable
across glibc 2.35+ systems. The shipped `install.sh`
deliberately does not trust the locally-built binary; it
downloads from the release.

For Alpine (musl-libc), a separate
`mathc-linux-x86_64-musl` variant ships as a release asset
since v3.2.0-alpha; the musl Docker image is deferred to a
later cycle (see `decisions/docker-alpine-impl-pending.yaml`).
Until then, Alpine users download the musl binary directly
from the release's `assets/` list.

## See also

- `adoption/SKILL.md` — the canonical agent skill.
- `USAGE.md` — adoption runbook (binary install + first decision).
- `decisions/install-tooling-2026-10.yaml` — the decision
  that introduces these four channels.
- `OCAML_BEST_PRACTICES.md` §11.28 (`curl | sh` install
  script and the `-fSL` flag discipline).