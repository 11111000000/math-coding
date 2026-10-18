# Adopting math-coding

> New here? Read [QUICKSTART.md](QUICKSTART.md) first.

A short guide for bringing an existing repository under the
math-coding protocol. For AI-agent adoption see the canonical skill at
[`adoption/SKILL.md`](adoption/SKILL.md).

## Install

> Native channels first; Docker as fallback. If none of the native channels work, see [If the native install fails](#if-the-native-install-fails) below.

Four ways to get `mathc` (`bin/mathc.exe` once compiled); see
[`site/install.md`](site/install.md) for the long-form guide
with sandbox notes and migration steps.

- **Release binary** (recommended). One-line install:
  ```sh
  curl -fsSL https://github.com/11111000000/math-coding/releases/latest/download/install.sh | sh
  ```
  Cross-platform — works on Linux (glibc + musl auto-detect),
  macOS, WSL, Git-Bash, MSYS, Cygwin. The script downloads
  `SHA256SUMS` and the matching `mathc-<os>-<arch>` from the
  same release, verifies the binary's digest, installs to
  `~/.local/bin/mathc`, and idempotently appends a PATH line
  to `~/.bashrc` / `~/.zshrc` / `~/.profile`. Pass
  `--user-skill` to also install the per-user opencode
  skill (`~/.config/opencode/skills/math-coding/SKILL.md`).
  Use `--no-path-update` to skip the shell RC edit.
  See [`scripts/install-tooling/install.sh`](scripts/install-tooling/install.sh)
  for the full flag set.
- **PowerShell** (Windows 10+ / 11). One-liner:
  ```powershell
  irm https://github.com/11111000000/math-coding/releases/latest/download/install.ps1 | iex
  ```
  Mirrors `install.sh`: downloads `SHA256SUMS`, verifies the
  Windows binary, installs to
  `%LOCALAPPDATA%\Programs\mathc\mathc.exe`, adds the dir
  to user `Path`. Optional `-UserSkill`, `-Upgrade`,
  `-NoCosignVerify`, `-NoPathUpdate`, `-Check`, `-WhatIf`.
  See [`scripts/install-tooling/install.ps1`](scripts/install-tooling/install.ps1).
- **Docker image** (sandbox-friendly). No sudo required:
  ```sh
  docker run --rm -v "$PWD:/repo" ghcr.io/11111000000/mathc:edge \
    validate decisions/foo.yaml
  ```
  The image is built from `Dockerfile.debian-slim` (multi-stage:
  nix-build → debian:bookworm-slim runtime).
- **Nix run** (zero-install for Nix users):
  ```sh
  nix run github:11111000000/math-coding -- validate decisions/foo.yaml
  ```
  `flake.nix` exposes `apps.<system>.default` for this path.
- **Source build** (kernel developers):
  ```sh
  nix develop .#test && dune build --root . bin/mathc.exe
  ```
  The resulting binary lands at
  `_build/install/default/bin/mathc`. **Warning:** per
  [`OCAML_BEST_PRACTICES.md`](OCAML_BEST_PRACTICES.md) §11.22,
  the locally-built binary links against nix-store glibc and
  is **not portable** across hosts whose system glibc is older
  than the nix-store version. Always download from the GitHub
  release for cross-host portability.

## If the native install fails

If `curl | sh`, the Windows installer, `nix run`, or the
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
`<VERSION>` with a release tag (e.g., `v3.3.3`) or `edge`
for the most recent main commit. The `:edge` tag is
rebuilt and republished on every push to `main`; a daily
healthcheck workflow asserts the image is still runnable.

## Quick start

If you want an AI coding agent (opencode, Claude Code, Cursor,
GitHub Copilot) to apply math-coding in your repository, copy the
matching file from the latest release tarball under
`dist/adoption/<platform>/` into the path named in
[`adoption/SKILL.md`](adoption/SKILL.md) §"Deploy this skill to your
platform". The skill walks the agent through four steps: install `mathc`,
bootstrap the repo, author one decision, run `mathc self-check`.

New projects get `.math-coding/` by default (since v3.4); projects
that already have `decisions/` and `attestations/` at the repo root
(from a pre-3.4 release) work as-is — the kernel falls back to the
legacy layout when `.math-coding/` is absent. No migration needed.

For manual adoption, follow the same four steps by reading the skill.

### Greenfield: `mathc init`

The fastest path for a new project. `mathc init` scaffolds a
math-coding project in one command:

```sh
cd /path/to/new-project
mathc init . --no-install         # scaffold without pre-commit hook
mathc validate .math-coding/policy.yaml   # verify the scaffolded policy
```

What `mathc init` does (v3.4 default layout):

- creates `.math-coding/decisions/` and `.math-coding/attestations/`
  (one folder instead of three at the repo root)
- writes `.math-coding/policy.yaml` with the active policy
  (a verbatim copy of
  `scripts/install-tooling/templates/active-policy.yaml`,
  which is `math-coding/3.2`)
- installs `.githooks/pre-commit` (unless `--no-install`) that
  runs `mathc validate` on staged decisions and `mathc self-check`
- **refuses** on `docs/arc42/`, `docs/adr/`, or `adr/` presence
  unless `--merge` is passed (use `--merge` for the brownfield
  arc42 / MADR / adr-tools path; see below)

To opt into the legacy `decisions/` + `attestations/` layout for a
specific call, pass the env-var overrides before `mathc init`:

```sh
MATH_CODING_DECISIONS_DIR=decisions \
MATH_CODING_ATTESTATIONS_DIR=attestations \
MATH_CODING_POLICY=decisions/decision.yaml \
  mathc init . --no-install
```

The full env-var matrix is documented in
[`adoption/SKILL.md`](adoption/SKILL.md) §"Environment variables";
the resolver precedence (env-var → new default → legacy fallback)
is implemented in `lib/path_config.ml`.

### Brownfield: `mathc import-adr`

For projects that already track decisions in MADR
(`docs/adr/NNNN-title.md`) or adr-tools
(`adr/NNNN-title.md` with `## Status` / `## Context` /
`## Decision` / `## Consequences` sections), `mathc import-adr`
emits a math-coding decision YAML for each existing ADR:

```sh
# Single file
mathc import-adr docs/adr/0001-use-postgres.md

# All MADR files in docs/adr/ (loop in your shell)
for f in docs/adr/*.md; do
  mathc import-adr "$f" --write   # writes to decisions/<id>.yaml
done
```

The output passes `mathc validate` after the reviewer fills in
`scope.paths[]` (left as a placeholder glob in the template).
The mapping is best-effort, not lossless; the reviewer
adjusts fields like `commitment` and `outcomes[]` to capture
the original ADR's intent. The decision retains a
`kind_: review` attestation of provenance in `assumptions[]`.

### Brownfield: Slack / Confluence

For projects whose decisions live in Slack threads or
Confluence pages (not in `docs/adr/`), two helper scripts
turn the export into MADR-shaped markdown, then the regular
`mathc import-adr` pipeline takes over:

```sh
# 1. Export from Slack (workspace settings → "Export data")
#    or Confluence (Space settings → "Export space").
#    Slack produces a zip; Confluence produces a JSON file.

# 2. Run the converter script. It writes one MADR-shaped
#    .md per decision-like message (Slack: thread starter
#    with >= 1 reply OR >= 2 reactions) or per page
#    (Confluence). TBD sections mark what the reviewer must
#    extract from the source.
python3 scripts/slack2madr.py <slack-export.zip> out/
python3 scripts/confluence2madr.py <confluence-export.json> out/

# 3. Reviewer fills the TBD sections in each .md, then
#    imports it via the regular pipeline.
for f in out/*.md; do
  mathc import-adr "$f" --write
done
```

The two scripts live under `scripts/` and use only the
Python 3 standard library (`zipfile`, `json`, `re`, `html.parser`,
`pathlib`). Cram tests in `tests/scripts/slack2madr.t` and
`tests/scripts/confluence2madr.t` assert the frontmatter
shape and section headings on a fixture; the reviewer
responsibility is to fill the TBD sections before
`mathc import-adr` so the kernel sees a complete MADR body.

## Choose your adoption path

Math-coding pays off when its applicability envelope is positive; for
projects below that threshold it is overhead, not insurance. The
envelope ([`spec/algebra-3.2.md`](spec/algebra-3.2.md) §28) treats
applicability as a sum over signals:

- Multi-agent AI-assisted development: highly applicable. Two or more
  agents editing the same repo need a shared authority model more
  than humans do.
- Critical infrastructure with a 3+ person team and a 5+ year
  lifetime: applicable. Decisions outlive the people who wrote them.
- Regulatory or contractual audit requirements: mandatory applicable.
  The attestation store and blocking gate are the audit trail.
- Solo or small team with no AI agents: low applicability. A
  changelog plus code review is usually enough.
- Prototypes, MVPs, throwaway tools, hackathon code: not applicable.
  Skip the methodology.

### Decision question

> Does your project coordinate two or more AI agents, require
> regulatory audit, or will it live five or more years with three or
> more contributors?
> Yes → Path A. No → Path B.

### Path A — full math-coding 3.3

For applicable projects. The full ceremony is justified.

- Install the kernel binary from the
  [GitHub releases page](https://github.com/11111000000/math-coding/releases).
  On Linux the binary is built against Ubuntu-22.04 system glibc
  (`mathc-linux-x86_64`, `mathc-linux-aarch64`). On systems with
  older glibc or musl-libc (Alpine), the glibc binary may fail
  with `GLIBC_X.Y not found`. A musl-linked variant
  (`mathc-linux-x86_64-musl`) was attempted via `feature/portable-musl-build`
  but reverted in v3.3 (see `decisions/portable-linux-musl.yaml`
  reversal signal `alpine-ci-build-fails`); the CI build pipeline
  was unable to drive the Alpine container's opam setup end-to-end.
  A future release will re-attempt.
- Use the AI-agent skill from
  [`adoption/SKILL.md`](adoption/SKILL.md) (preferred) or follow the
  four steps in it manually.
- Wire the blocking `mathc self-check` into CI per the project's
  [`.github/workflows/ci.yml`](https://github.com/11111000000/math-coding/blob/main/.github/workflows/ci.yml).
- Populate the attestation store on day one so the gate goes green.

### Site publish one-time setup

The protocol's published surface lives at
[11111000000.github.io/math-coding/](https://11111000000.github.io/math-coding/).
On a fresh repo the site pipeline needs a single one-time enablement
in **Settings → Pages → Build and deployment → Source**: pick
**GitHub Actions** (not "Deploy from a branch"). Once set, every push
to `main` triggers `.github/workflows/site.yml`, which runs
`scripts/render.sh` and publishes `dist/` to Pages via
`actions/deploy-pages@v4`. The Pages environment binding is
`github-pages` with OIDC (`id-token: write`). No branch selection,
no `gh-pages` branch, no personal token.

### Path B — regular ADR plus counterexamples

For low-applicability projects. A standard architectural decision
record, one counterexample paragraph, and a human reviewer. No kernel
binary, no blocking gate, no attestation store.

- Write the ADR with `context`, `decision`, `consequences`, `risk`,
  `owner` — the MADR or adr-tools shape.
- Add a `## Counterexample` paragraph: the strongest plausible case
  where this decision is wrong, and what would change your verdict.
- Reviewer marks the PR **pass** or **request changes**; their
  verdict is the attestation.
- CI logs and the git history are the evidence trail. No JSON store
  is required.

### Migrating between paths

The two paths are not mutually exclusive. A project can start on
Path B and migrate to Path A when applicability increases — adding
AI agents, growing the team, taking on a regulated customer. The
reverse is also valid: if math-coding becomes overhead (the project
shrinks, the audit requirement ends), rip out `decisions/`,
`attestations/`, and the gate workflow. A clean revert is itself
evidence that the kernel did not capture you.

### Hotfix procedure

When the SLA is the developer: a CVE needs a fix in < 1h, or
an incident demands an urgent merge before the post-hoc decision
+ attestation can be authored. The `scripts/hotfix-cve.sh` wrapper
stamps a 24h waiver at `decisions/waivers/hotfix-<ticket>.yaml`
under the existing `math-coding/waiver-3.3` schema (the kernel
loader is `lib/waiver.ml`).

```bash
scripts/hotfix-cve.sh CVE-2026-1234     # writes a 24h waiver
mathc validate decisions/waivers/hotfix-CVE-2026-1234.yaml   # exit 0
```

Within the 24h window the developer MUST follow up with:

1. `decisions/<id>.yaml` — the post-hoc decision describing the
   change. Use `mathc new-decision <id>` (or
   `--template=minimal` for short forms).
2. `attestations/<id>-<obligation>.json` — the matching
   attestation (kind `test` / `review` / `build` / `analysis`).

If the post-hoc pair does not land before `expires_at`, the
waiver stops being effective_at and the next `mathc gate` returns
Block on this subject. The compensating control surface is
`decisions/waivers/hotfix-*.yaml` in the next-actions report; a
hotfix older than 24h is a remediation item, not a clean tree.

## AI agents

The `mathc` binary ships with a companion `mathc_mcp` JSON-RPC 2.0
server over stdio. The server exposes 11 `mathc/<name>` methods
(see `adoption/SKILL.md` §"MCP integration" for the full list and
the launch command). An MCP-aware agent (opencode, Claude Code,
Cursor) can launch `mathc_mcp` as a stdio MCP server and call
`mathc::validate`, `mathc::self-check`, etc. as direct tool calls
without a `bash` shell round-trip.

For a brownfield project with many existing decisions and zero
attestations, the fastest path to a green `mathc self-check` is
`mathc attest-batch`:

```sh
# Generate one review-class attestation per obligation under
# .math-coding/decisions (or $MATH_CODING_DECISIONS_DIR if set).
mathc attest-batch --from=decisions \
  --kind=review \
  --producer=human:integration-experiment \
  --result=pass
```

For a per-project, human-reviewed audit, point `--manifest` at a
TSV file the agent authors with explicit rows; see
[`adoption/SKILL.md`](adoption/SKILL.md) §"Bulk attestations:
`mathc attest-batch`" for the manifest format.

## Review-time questions

Before declaring a change ready, a reviewer should answer four
questions, in this order:

1. Does the diff touch only files in `scope.paths[]`? If not, the
   decision does not authorise it.
2. Does every new artifact pass `mathc validate` against its JSON Schema?
3. Does each obligation name a fixture path that is present and green?
4. Does `mathc self-check` pass on the branch HEAD?

A `no` on any of these is a block, not a waiver. AI agents walking
the same checks find the questions enumerated at the top of
[`adoption/SKILL.md`](adoption/SKILL.md) §"Step 4".

If `mathc validate` or `mathc self-check` exits non-zero, the stderr
line starts with an `MC-*` code. Run `mathc explain-diagnostic <CODE>`
to get the remediation steps for that code.

## What the kernel refuses

The constitution lists 14 invariants; the most common refusals are
enumerated in [`adoption/SKILL.md`](adoption/SKILL.md) §"What the
kernel refuses" (missing result, missing obligation, missing fixture,
missing authority, missing expiry, silent promotion). Full list:
[`spec/constitution.md`](spec/constitution.md) §"Kernel Invariants".