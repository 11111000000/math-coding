---
name: math-coding
description: |
  Apply the math-coding assurance protocol in a project. Use when the user
  says "примени math-coding", "set up math-coding", "start tracking
  decisions", "we need an audit trail", or mentions obligations,
  attestations, or waiver in a project context. Do not trigger on casual
  uses of "decision" or "obligation" in ordinary conversation.
compatible_with: mathc@>=3.1.0
---

# math-coding

Math-coding binds every change to a written commitment, a list of
obligations, and bounded evidence. The kernel (`mathc`) checks that
nothing is silently promoted from `unknown` to `pass`.

The protocol does not prove software correctness. It refuses to.

## When to apply

Use this skill when at least one of these is true:

- Two or more AI agents (or humans) edit the same repository and need a
  shared authority model.
- Regulatory or contractual audit requires a tamper-evident trail.
- A team of three or more will maintain the project for five or more
  years; decisions must outlive the people who wrote them.

## When not to apply

Skip this skill and use a plain ADR (`MADR` or `adr-tools` shape with a
`## Counterexample` paragraph) when:

- The project is a prototype, MVP, hackathon, or throwaway script.
- A single person maintains it without AI assistance.
- The audit requirement is informal (a code reviewer's "lgtm" is enough).

If unsure: start with a plain ADR. Migrate to math-coding later by
copying the existing decisions into `decisions/*.yaml` and adopting the
schema. The migration cost is one decision and one CI change.

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

If `~/.local/bin` is not on `$PATH`, the line above sets it for the
current shell. Add it to your shell rc (`~/.bashrc`, `~/.zshrc`) for
permanence.

## Step 2. Bootstrap the repository

Check whether `decisions/` already exists. If it does, skip to step 3.

If not, create the minimum:

```bash
mkdir -p decisions attestations

# Copy the active policy from the math-coding repo.
curl -fsSL https://raw.githubusercontent.com/11111000000/math-coding/main/decisions/decision.yaml \
  > decisions/decision.yaml

# Adjust scope.paths[] to match this repository's source tree.
$EDITOR decisions/decision.yaml
```

`mathc version` should print `math-coding <version>: bootstrap` and
exit 0 on the current release. If it does not, the binary you downloaded
is not the same release as this skill; see `compatible_with` in the
frontmatter above.

## Step 3. First decision

Create `decisions/<id>.yaml` using the template below. Replace `<id>`
with a kebab-case identifier (lowercase letters, digits, dashes; 1 to
128 chars). Example: `jwt-rotation`, `no-tailwind`, `drop-legacy-api`.

```yaml
---
schema: math-coding/3.2
id: <id>
revision: 1

intent: |
  One paragraph. What should become true after this decision lands?

commitment: |
  Two sentences max. What is promised. If you cannot phrase it in two
  sentences, the decision is not ready.

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
  "obligation": "<obligation-id>",
  "method": "dune-runtest",
  "result": "pass",
  "material_digests": []
}
```

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

- `decisions/*.yaml` — the commitments.
- `attestations/*.json` — the evidence.
- `schemas/*.json` — only if the local copy is pinned to an older
  version; otherwise leave alone.

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

