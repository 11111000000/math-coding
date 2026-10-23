---
name: math-coding
description: |
  Apply the math-coding assurance protocol in a project. Use when the user
  says "примени math-coding", "set up math-coding", "start tracking
  decisions", "we need an audit trail", or mentions obligations,
  attestations, or waiver in a project context. Do not trigger on casual
  uses of "decision" or "obligation" in ordinary conversation.
compatible_with: mathc@>=3.6.0
MC_VERSION=3.6.0
---

# math-coding

Math-coding binds every change to a written commitment, a list of
obligations, and bounded evidence. The kernel (`mathc`) checks that
nothing is silently promoted from `unknown` to `pass`.

The protocol does not prove software correctness. It refuses to.

## When to apply

Default: apply. The kernel goes into a project that is expected to
still exist next month — including a project with exactly one
maintainer. Per `spec/algebra-3.2.md` §28 the burden of proof sits
on the exclusion, not on the adoption: to skip this skill you must
name the project as throwaway, not as small.

Signals that lift the ceremony above the light floor:

- Two or more AI agents (or humans) edit the same repository and need a
  shared authority model.
- Regulatory or contractual audit requires a tamper-evident trail.
- A team of three or more will maintain the project for five or more
  years; decisions must outlive the people who wrote them.
- An AI agent writes into the repository, even when there is one human.
  Code you did not write is code you cannot recall; the counterexample
  paragraph is where you find out it was wrong.

## When not to apply

Exactly one class — `prototype_or_throwaway(P)` in §28, i.e. the
project has no expected continuity:

- The project is a prototype, MVP, hackathon, or throwaway script
  whose code nobody will read again after the next refactor.

That is the whole list. "Only one maintainer", "no formal audit", and
"an informal lgtm is enough" are no longer exclusion criteria. A solo
maintainer declares `mode_floor: light` in the project's
`policies.yaml` and gets the cheapest rung of Path A — per-commit cost
is `{commitment, counterexample}` and a `decision:<id>@<rev>` git
trailer satisfies the gate without a sibling YAML — rather than an
opt-out that leaves nothing behind.

Skipping requires stating the throwaway rationale where a reader will
find it (the project README, or the commit that starts the project).
Everything else: run `mathc init .` — it prints the envelope it
assumed, so the choice lands in the record instead of in a habit.

## Step 1. Install the kernel

```bash
# Single-line install (default tag is the rolling 'edge' prerelease).
# The script verifies SHA-256 of the downloaded binary against
# SHA256SUMS on the same release. To pin a specific tag, pass
# --version=<X>; to also install the per-user opencode skill, pass
# --user-skill. See https://11111000000.github.io/math-coding/install.html
# for the full matrix (release / Docker / Nix / source build).
curl -fsSL https://github.com/11111000000/math-coding/releases/download/edge/install.sh \
  | sh -s -- --user-skill
export PATH="$HOME/.local/bin:$PATH"
mathc version
```

> For Docker or Nix: see USAGE.md §Install. For a three-command
> quickstart of the whole adoption, see [QUICKSTART.md](QUICKSTART.md).

If `~/.local/bin` is not on `$PATH`, the line above sets it for the
current shell. Add it to your shell rc (`~/.bashrc`, `~/.zshrc`) for
permanence.

## Step 2. Bootstrap the repository

For a new project, prefer `mathc init .` — it scaffolds
`.math-coding/decisions/`, `.math-coding/attestations/`,
`.math-coding/policy.yaml`, and (unless `--no-install`) the
`.githooks/pre-commit` hook. This is the v3.4 default layout; the
artifact tree is one directory instead of three.

For a brownfield project (an existing `decisions/` and `attestations/`
at the repo root from a pre-3.4 release), do not migrate
unnecessarily. The kernel's `lib/path_config.ml` resolver uses the
new `.math-coding/` defaults when they exist, and falls back to the
legacy `decisions/` + `attestations/` layout when `.math-coding/` is
absent (see [§"Backward compatibility"](#backward-compatibility)
below). Run `mathc validate decisions/decision.yaml` to confirm the
kernel still sees your existing tree.

If you are manual-bootstrapping a greenfield project without
`mathc init`, the minimum to create is:

```bash
mkdir -p .math-coding/decisions .math-coding/attestations

# Copy the active policy from the math-coding repo.
curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/decisions/decision.yaml \
  > .math-coding/policy.yaml

# Adjust scope.paths[] to match this repository's source tree.
$EDITOR .math-coding/policy.yaml
```

To force the legacy layout for an explicit reason (e.g. matching an
older CI that scans `decisions/`), set the env-var override before
init or use the resolver at runtime:

```bash
MATH_CODING_DECISIONS_DIR=decisions \
MATH_CODING_ATTESTATIONS_DIR=attestations \
MATH_CODING_POLICY=decisions/decision.yaml \
  mathc validate decisions/decision.yaml
```

`mathc version` should print `math-coding <version>: bootstrap` and
exit 0 on the current release. If it does not, the binary you downloaded
is not the same release as this skill; see `compatible_with` in the
frontmatter above.

## Step 3. First decision

Create `decisions/<id>.yaml` using the template below. Replace `<id>`
with a kebab-case identifier (lowercase letters, digits, dashes; 1 to
128 chars). Example: `jwt-rotation`, `no-tailwind`, `drop-legacy-api`.

The `axiom_link` and `counterexample` fields are **required when
`state=active`** (the default). The kernel emits
`MC-COUNTEREXAMPLE-MISSING` (Block) before `MC-MISSING-INTENT`
because axiom A3 orders counterexample first: the strongest
objection to the commitment must be on the page when a reviewer
reads it.

```yaml
---
schema: math-coding/3.3
id: <id>
revision: 1

intent: |
  One paragraph. What should become true after this decision lands?

commitment: |
  Two sentences max. What is promised. If you cannot phrase it in two
  sentences, the decision is not ready.

axiom_link:
  - A0
  - A3
counterexample: |
  State the strongest plausible case where this decision is wrong, and
  what would change your verdict. One paragraph. Empty here means the
  reviewer is reading the commitment without its counterweight.

outcomes:
  - id: <outcome-id>
    statement: |
      One sentence. The observable property this decision delivers.

scope:
  paths:
    - "<path/glob/that/this/decision/touches/**>"

obligations:
  - id: <obligation-id>
    claim: |
      One sentence. What the kernel or fixture can verify.
    acceptance:
      all:
        - verifier: <fixture-path-or-kernel-verifier>
          result: pass

risk:
  declared_triggers:
    - <what-could-go-wrong>
  owner: <human:role or human:name>

relations:
  addresses:
    - bootstrap-v3@3
```

### Step 3.5. Minimal form

For a one-shot decision (5-7 user-editable fields), use
`--template=minimal` to emit the 13-line stub on schema
`math-coding/3.3`:

```bash
mathc new-decision my-id --template=minimal
```

The stub has the same shape as the canonical template above but
emits TODO markers in every field the user must fill in. The
stub passes `mathc validate` (with the
`deficit/MC-COUNTEREXAMPLE-MISSING` soft warning) because the
kernel-required defaults (`mode: light`, `axiom_link: [A0]`,
`risk.owner`) are baked in. The user is expected to fill in
the TODO markers and re-run `mathc validate` after their first
edit. The full template (`--template=full`, the default) is
preserved for backward compatibility with existing adopters.

## Step 4. Validate and self-check

```bash
mathc validate decisions/<id>.yaml   # exits 0 on accept, 1 on reject, 2 on input
mathc self-check                     # exits 0 on pass; non-zero blocks merge
```

On a non-zero exit, the stderr line starts with an `MC-*` code. Run
`mathc explain-diagnostic <CODE>` to get the remediation steps (Definition,
Occurs when, Remediation) for that code.

The first `mathc self-check` after a fresh bootstrap may return `stale`
because no attestation has been recorded yet. That is expected; the
gate does not block until a policy change makes a missing attestation
an obligation.

To record an attestation when one is owed, write a file under
`attestations/` matching `schemas/attestation.json`:

```json
{
  "schema": "math-coding/attestation-3.0-alpha",
  "kind": "attestation",
  "subject": {
    "decision": "<decision-id>@1",
    "obligation": "<obligation-id>",
    "candidate_tree": "HEAD",
    "materials_digest": ""
  },
  "kind_": "test",
  "producer": { "identity": "ci:bot" },
  "result": "pass",
  "issued_at": "<ISO-8601 timestamp>",
  "id": "sha256:<64 hex chars>"
}
```

The attestation `id` is the SHA-256 of the file content with the
`id` field treated as a 64-zero placeholder (the same convention
as the decision `body_sha`); `mathc attest` writes the field
correctly. See `lib/attestations/attestations.ml` for the parser
and `attestations/ux-3-*.json` for canonical examples.

### Bulk attestations: `mathc attest-batch`

For brownfield projects with many obligations, hand-writing one
attestation JSON per obligation is slow and error-prone.
`mathc attest-batch` generates the JSONs from a TSV manifest or
by walking `MATH_CODING_DECISIONS_DIR` directly:

```bash
# Walk every obligation under the decisions dir (default
# .math-coding/decisions). One attestation per obligation.
mathc attest-batch --from=decisions --kind=review --producer=human:me

# Read a TSV manifest: 4 required columns + 1 optional result.
# decision_id<TAB>obligation_id<TAB>kind_<TAB>producer_identity[<TAB>result]
mathc attest-batch --manifest=manifest.tsv

# Emit JSON to stdout, do not write files.
mathc attest-batch --from=decisions --dry-run
```

Manifest format (TSV):

```text
decision_id<TAB>obligation_id<TAB>kind_<TAB>producer_identity[<TAB>result]
```

| Column | Required | Notes |
|---|---|---|
| `decision_id` | yes | matches the decision YAML `id` |
| `obligation_id` | yes | matches one `obligations[].id` |
| `kind_` | yes | one of `review`, `test`, `build`, `analysis`, `observation` |
| `producer_identity` | yes | e.g. `ci:bot`, `human:tester` |
| `result` | no | defaults to `pass`; `pass` or `fail` |

Output: one JSON file per row, written to
`MATH_CODING_ATTESTATIONS_DIR` (default
`.math-coding/attestations/`) as `<decision>-<obligation>.json`.
The output schema string is `math-coding/attestation-3.3`; the
SHA-256 `id` field is computed from the canonical JSON body
(sorted keys, no whitespace), matching the upstream Python
`scripts/generate-attestations.py` byte-for-byte at the digest
boundary. Pure parsing lives in `lib/attestations/batch.ml`;
cram fixtures in `tests/cli/attest-batch*.t` cover the positive,
negative, and `--dry-run` paths.

## What the kernel refuses

These five outcomes are how the kernel says "no":

- **missing result** — a decision without `obligations[]`.
- **missing obligation** — an obligation without `acceptance.verifier`.
- **missing fixture** — a verifier naming a path that does not exist.
- **missing authority** — a protected-policy transition not under the
  previously active policy.
- **missing expiry** — a waiver without `expires_at`.

`unknown`, `waived`, and `reviewed` are not `pass`. The kernel will not
silently promote them.

## Files you touch

You only edit these in the target repository:

- `.math-coding/decisions/*.yaml` — the commitments (or
  `decisions/*.yaml` on the pre-3.4 legacy layout).
- `.math-coding/attestations/*.json` — the evidence (or
  `attestations/*.json` on the pre-3.4 legacy layout).
- `.math-coding/policy.yaml` — the active policy (or
  `decisions/decision.yaml` on the pre-3.4 legacy layout).
- **NOT** `schemas/*.json` — they were embedded into the kernel
  in v3.4 (`lib/schema_embedded.ml`); a brownfield repository does
  not need `schemas/` on disk for `mathc validate` to work. Only
  pin a local copy if you are deliberately targeting a pre-v3.4
  schema version.

You do not read or edit `spec/`, `axioms/`, `lib/`, or any
math-coding-internal documentation while adopting the protocol in a
different project. Those exist for the people who maintain the kernel
itself.

## Deploy this skill to your platform

This file is the canonical skill. To use it in another agent platform,
copy the platform-specific file from the math-coding release tarball
under `dist/adoption/<platform>/` into the matching path:

| Platform | Target path |
|---|---|
| opencode | `.opencode/skills/math-coding/SKILL.md` |
| Claude Code | `CLAUDE.md` (merge snippet) or `.claude/instructions.md` |
| Cursor | `.cursor/rules/math-coding.md` |
| GitHub Copilot | `.github/instructions/math-coding.instructions.md` |

If you cannot copy a file (the agent session is read-only), ask the
user to paste the file from `dist/adoption/<platform>/` into the path
above. The agent must not edit the source repository's internal docs.
## MCP integration

The `mathc` binary ships with a companion `mathc_mcp` JSON-RPC 2.0 server
over stdio. The server exposes 11 `mathc/<name>` methods:

  mathc/validate, mathc/explain, mathc/packages, mathc/mode,
  mathc/re-evaluate, mathc/rebuttals, mathc/self-check,
  mathc/gate, mathc/attest, mathc/record,
  mathc/re-evaluate-decisions

Read-only methods (validate, explain, packages, mode, re-evaluate,
rebuttals, self-check) are listed at
`decisions/mcp-server-impl-2026-10.yaml`. Read-write methods (gate,
attest, record, re-evaluate-decisions) are listed at
`ux-3-mcp-read-write-2026-10.yaml`. Both are emitted from the same
allowlist in `lib/mcp/dispatch.ml`.

Wire protocol: one JSON-RPC request per line on stdin, one response
per line on stdout. stderr is reserved for server diagnostics.
EOF-on-stdin exits cleanly with code 0.

The MCP server shell-out to the `mathc` binary is resolved via
`Sys.executable_name` (strip the `_mcp` suffix); the mathc install
path installs both `mathc` and `mathc_mcp` side-by-side. Launch
the server directly:

  $ ~/.local/bin/mathc_mcp     # reads JSON-RPC from stdin, writes to stdout

An MCP-aware agent (opencode, Claude Code, Cursor) can launch this
binary as a stdio MCP server. The agent then sees `mathc::validate`
et al. as direct tool calls, without a `bash` shell round-trip.

### Read-write gating via `MCP_READ_WRITE`

The four read-write methods (`mathc/gate`, `mathc/attest`,
`mathc/record`, `mathc/re-evaluate-decisions`) produce side
effects (writes to `attestations/` and `decisions/execution-logs.jsonl`).
A strict agent host can disable them by setting
`MCP_READ_WRITE=off` (or any value other than `on`, `true`,
`1`, or unset) before launching `mathc_mcp`. The four methods
then return `-32601 Method not found` with a message that
names the env var; the seven read-only methods plus
`mathc/find` continue to work. The default (env unset) keeps
all 11 methods reachable, so existing agent hosts are
unaffected. Operators who want a one-shot warning when the
gate is off can also inspect stderr — the server prints
`mathc_mcp: MCP_READ_WRITE=<value> — read-write methods disabled.`
exactly once per process.

## Environment variables

The kernel reads four environment variables at startup. Three are
implemented in `lib/path_config.ml` and consulted by every site that
needs to find a decisions / attestations / policy path; the fourth
documents the planned location for system-wide templates and
schemas.

| Variable | Default | Purpose |
|---|---|---|
| `MATH_CODING_DECISIONS_DIR` | `.math-coding/decisions` | Where the kernel reads and writes `*.yaml` decisions. Set explicitly to override (e.g. `=decisions` for the legacy layout). |
| `MATH_CODING_ATTESTATIONS_DIR` | `.math-coding/attestations` | Where the kernel reads and writes `*.json` attestations. |
| `MATH_CODING_POLICY` | `.math-coding/policy.yaml` | Master policy path consulted by `mathc validate` and `mathc self-check`. |
| `MATH_CODING_HOME` | `$XDG_DATA_HOME/math-coding/<version>` | System-wide templates and schema directory (planned for v3.5; not yet consulted at runtime). |

Precedence in the resolver (`lib/path_config.ml::resolve_with`):

1. The env-var, if set to a non-empty value: wins unconditionally.
   No filesystem check; a typo surfaces at the call site, not here.
2. The new-default path (`.math-coding/...`), if it exists on disk.
3. The legacy fallback (`decisions/`, `attestations/`,
   `decisions/decision.yaml`), if it exists on disk.
4. The new-default path, synthesised (so a fresh `mathc init`
   against an empty directory still creates `.math-coding/`).

The resolver returns *relative* paths; callers compose with
`Filename.concat root ...` as before. See
[`lib/path_config.ml`](lib/path_config.ml) for the exact three-tier
contract and PLAN.md §0.1 for the original design notes.

## Backward compatibility

Projects bootstrapped against any 3.0–3.3 release — those with
`decisions/` and `attestations/` at the repo root and a master policy
at `decisions/decision.yaml` — continue to work without any
configuration change on 3.4:

- The kernel resolver prefers `.math-coding/...` when present,
  but falls back to `decisions/` and `attestations/` when
  `.math-coding/` is absent. No migration, no auto-rename, no
  deprecation warning at `mathc validate` time.
- `mathc attest` and `mathc attest-batch` write to the same
  directory the kernel reads from; legacy stores are not re-rooted.
- `mathc init` on a project that already has `decisions/`
  succeeds and emits a clean tree under `.math-coding/`, leaving
  the legacy tree in place — they coexist until the operator
  removes one. `mathc init --merge` (planned, not yet wired in
  v3.4) will offer an explicit deletion step.

To opt into the legacy layout explicitly — for a CI that scans
`decisions/` for instance — set the env-var override before the
mathc command:

```bash
export MATH_CODING_DECISIONS_DIR=decisions
export MATH_CODING_ATTESTATIONS_DIR=attestations
export MATH_CODING_POLICY=decisions/decision.yaml
mathc validate decisions/<id>.yaml
```

The resolver honours these names whether or not the named
directory exists; the env-var wins, the filesystem is not
consulted for that variable. This makes hermetic cram tests
trivial: `export MATH_CODING_DECISIONS_DIR=.test-math-coding/decisions`
is the recommended invocation in `tests/cli/*.t`.

