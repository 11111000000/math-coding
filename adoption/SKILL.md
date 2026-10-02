---
name: math-coding
description: |
  Apply the math-coding assurance protocol in a project. Use when the user
  says "примени math-coding", "set up math-coding", "start tracking
  decisions", "we need an audit trail", or mentions obligations,
  attestations, or waiver in a project context. Do not trigger on casual
  uses of "decision" or "obligation" in ordinary conversation.
compatible_with: mc@>=3.0.0.20
---

# math-coding

Math-coding binds every change to a written commitment, a list of
obligations, and bounded evidence. The kernel (`mc`) checks that
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
# Pick the release tag that matches this skill. The release page lists
# binaries for linux-amd64, linux-arm64, macos-amd64, macos-arm64.
MC_VERSION=3.0.0.20
URL="https://github.com/11111000000/math-coding/releases/download/v${MC_VERSION}"
wget -qO ~/.local/bin/mc "${URL}/mc-linux-amd64"
chmod +x ~/.local/bin/mc
export PATH="$HOME/.local/bin:$PATH"
mc version
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

`mc version` should print `math-coding 3.0-alpha: bootstrap` and exit 0
on the current release. If it does not, the binary you downloaded is
not the same release as this skill; see `compatible_with` in the
frontmatter above.

## Step 3. First decision

Create `decisions/<id>.yaml` using the template below. Replace `<id>`
with a kebab-case identifier (lowercase letters, digits, dashes; 1 to
128 chars). Example: `jwt-rotation`, `no-tailwind`, `drop-legacy-api`.

```yaml
---
schema: math-coding/3.0-alpha
id: <id>
revision: 1

intent: |
  One paragraph. What should become true after this decision lands?

commitment: |
  Two sentences max. What is promised. If you cannot phrase it in two
  sentences, the decision is not ready.

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
    - bootstrap-v3@2
```

## Step 4. Validate and self-check

```bash
mc validate decisions/<id>.yaml   # exits 0 on accept, 1 on reject, 2 on input
mc self-check                     # exits 0 on pass; non-zero blocks merge
```

The first `mc self-check` after a fresh bootstrap may return `stale`
because no attestation has been recorded yet. That is expected; the
gate does not block until a policy change makes a missing attestation
an obligation.

To record an attestation when one is owed, write a file under
`attestations/` matching `schemas/attestation.json`:

```json
{
  "schema": "math-coding/3.0-alpha",
  "kind": "attestation",
  "id": "<decision-id>-<obligation-id>",
  "decision": "<decision-id>@1",
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