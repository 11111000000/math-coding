# GitHub Pull Requests Integration

This document describes how math-coding packets work with
GitHub Pull Request workflow. The goal is **automatic structural
verification on every PR** plus human-readable PR descriptions.

## TL;DR

```yaml
# .github/workflows/verify.yml (already in the convention)
name: verify
on: [pull_request]
jobs:
  structural:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sh examples/self-application/verify-consistency.sh
```

This blocks merging if the convention is violated. No new
tooling required.

## What the integration does

### Automated: `verify` workflow

Runs on every push and PR. Validates:

- All `packet.yaml`, `task.md`, `assumptions.yaml` files
- All structural invariants in `core/core.md`
- JSON Schema meta-validation
- Encoding (UTF-8 LF, no BOM)

Exit 0 means **the convention holds**. Exit 1 means a packet
violates the convention — the verifier lists which.

### Required check

Configure branch protection:

```
Settings → Branches → main → Require status checks → "verify / structural"
```

This prevents merging when the verifier fails. Pull requests
without `verify / structural` are blocked.

### PR template

Add `.github/pull_request_template.md`:

```markdown
## What this PR does

## Math-Coding packets touched

<!-- List packet IDs this PR modifies -->

- [ ] packet1
- [ ] packet2

## Verifier run output

<!-- Paste the output of `sh examples/self-application/verify-consistency.sh` -->

## Decision rationale

<!-- Why this change? What alternatives were considered? -->

## Adaptations

<!-- If you deviated from the convention, document here -->

```

Agents reading this template will populate the **packets touched**
list automatically (by listing changed `packet.yaml` files).

### Auto-label

Add `.github/workflows/auto-label.yml`:

```yaml
name: auto-label
on: [pull_request]
jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/labeler@v5
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          configuration-path: .github/labeler.yml
```

`.github/labeler.yml`:

```yaml
packet-changed:
  - changed-files:
      - any-glob-to-any-file: '**/packet.yaml'
adr-changed:
  - changed-files:
      - any-glob-to-any-file: 'adr/**'
theory-changed:
  - changed-files:
      - any-glob-to-any-file: 'core/01-Theory/**'
schema-changed:
  - changed-files:
      - any-glob-to-any-file: 'schemas/**'
```

This automatically labels PRs by what kind of artifact they touch.

## Operational flow

When a developer works on a packet:

1. Create a branch (e.g., `feat/packet-XYZ`)
2. Edit the packet files
3. Open a PR
4. CI runs the verifier
5. If PASS: reviewer merges
6. If FAIL: developer fixes the packet, pushes again
7. Reviewer checks the PR template fields (especially **Decision
   rationale** and **Adaptations**)
8. Merge

When an AI agent works on a packet (e.g., Cursor or opencode):

1. Agent opens a packet following the process in `agents/agents.md`
2. Agent pushes to a branch
3. CI runs the verifier
4. Agent reads the verifier output
5. If FAIL: agent fixes the packet, pushes again
6. Agent signals human for review

## What the integration does NOT do

- **Does not write PR descriptions automatically.** Generating
  PR text from code is brittle; the template is the contract.
- **Does not assign reviewers.** Use CODEOWNERS for that.
- **Does not merge.** The verifier provides evidence; the
  reviewer makes the decision.

## CODEOWNERS (recommended)

`CODEOWNERS` at the repository root:

```
# AI agents own their packets by default
/artifacts/  @cursor-bot

# Theory documents are reviewed by a mathematician
/core/01-Theory/  @math-coder

# Schema changes require the verifier author
/schemas/  @verifier-author
```

GitHub assigns reviewers automatically when CODEOWNERS matches.

## Anti-patterns

- **Bypassing the verifier**: never use `gh pr merge --admin`
  to merge a failing PR. Fix the packet.
- **Mute the verifier**: never add `--quiet` to the verifier
  command. Every violation should be loud.
- **Wide commits**: prefer one packet per PR. Multiple packets
  in one PR make blame harder.

## References

- GitHub Actions documentation:
  <https://docs.github.com/en/actions>
- Branch protection rules:
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>
- Pull request templates:
  <https://docs.github.com/en/communities/using-templates-to-encourage-useful-issue-and-pull-requests/about-issue-and-pull-request-templates>