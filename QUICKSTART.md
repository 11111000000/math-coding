# Quickstart

Three commands from `curl | sh` to a green `mathc self-check`. For the
full runbook, see [USAGE.md](USAGE.md). For the AI-agent skill, see
[adoption/SKILL.md](adoption/SKILL.md).

## Install

> Native channels first; Docker as fallback. If none of the native channels work, see [If the native install fails](#if-the-native-install-fails) below.

The default channel is **stable** (the latest tagged
`vX.Y.Z` release, or the most recently published release
artifact if no stable tag exists yet). The `--channel=edge`
opt-in (`-Version edge` in PowerShell) installs the
rolling nightly prerelease.

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

Want the rolling prerelease instead of stable? Pass the
`edge` opt-in explicitly:

```sh
curl ... | sh -s -- --version=edge
```

```powershell
irm ... | iex -Version edge
```

Other channels (Docker, Nix, source build) live in
[site/install.md](site/install.md); use them when `curl | sh`
is blocked or you need a hermetic runner.

## If the native install fails

If `curl | sh`, the PowerShell installer, `nix run`, or the
source build does not work on your host (corporate proxy
blocking `raw.githubusercontent.com`, Alpine/musl libc,
immutable CI runner without write access to `~/.local/`),
the Docker image is the always-available fallback. The
image at `ghcr.io/11111000000/mathc:<VERSION>` is built
and signed by this repository's CI on every release tag
push; no installation to your host is required.

```sh
docker run --rm -v "$PWD:/repo" \
  ghcr.io/11111000000/mathc:<VERSION> \
  validate decisions/foo.yaml
```

The same command works for any subcommand. Replace
`<VERSION>` with a release tag (e.g., `v3.3.0`) or `edge`
for the most recent main commit.

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
  paths, migration between Path A and Path C.
- [adoption/SKILL.md](adoption/SKILL.md): the canonical agent skill.
- [site/install.md](site/install.md): sandbox notes, glibc / musl,
  Docker, Nix.
