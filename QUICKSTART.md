# Quickstart

Three commands from `curl | sh` to a green `mathc self-check`. For the
full runbook, see [USAGE.md](USAGE.md). For the AI-agent skill, see
[adoption/SKILL.md](adoption/SKILL.md).

## Install

Linux / macOS / WSL / Git-Bash / MSYS / Cygwin / Alpine — one
command, auto-detects libc and shell RC:

```sh
curl -fsSL https://github.com/11111000000/math-coding/releases/latest/download/install.sh \
  | sh -s -- --user-skill
mathc version
```

Windows (PowerShell 5.1+ / 7+):

```powershell
irm https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 | iex
mathc version
```

The shell installer:
- downloads `SHA256SUMS` and verifies the binary;
- installs to `~/.local/bin/mathc` (Linux/macOS) or
  `%LOCALAPPDATA%\Programs\mathc` (Windows);
- idempotently appends `export PATH=…` to `~/.bashrc` /
  `~/.zshrc` / `~/.profile` (Windows: user `Path`);
- on Alpine / Void / Chimera, downloads the musl-linked
  binary automatically.

Other channels (Docker, Nix, source build) live in
[site/install.md](site/install.md); use them when `curl | sh`
is blocked or you need a hermetic runner.

## First decision

Greenfield:

```sh
cd /path/to/new-project
mathc init . --no-install
mathc validate decisions/decision.yaml
```

Brownfield (existing MADR / adr-tools / arc42):

```sh
mathc init . --merge                       # explicit opt-in
# or
mathc import-adr docs/adr/0001-*.md --write   # MADR-shaped ADR
```

## Self-check

```sh
mathc self-check
```

Exits 0 on pass, 1 on fail, 3 on `unknown` (obligations recorded but
not yet attested). On a fresh bootstrap, `unknown` is expected: no
attestations exist yet. See [USAGE.md](USAGE.md) §"Review-time
questions" for the four questions every change must answer.

## Next

- [USAGE.md](USAGE.md): install channels, decision question, AI-agent
  paths, migration between Path A and Path B.
- [adoption/SKILL.md](adoption/SKILL.md): the canonical agent skill.
- [site/install.md](site/install.md): sandbox notes, glibc / musl,
  Docker, Nix.
