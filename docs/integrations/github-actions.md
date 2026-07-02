# GitHub Actions Integration

This document describes how math-coding works with GitHub
Actions (CI). The verifier runs in CI on every commit; failed
runs block merges when branch protection is enabled.

## TL;DR

The repo ships a `verify.yml` workflow at `.github/workflows/verify.yml`:

```yaml
name: verify
on: [push, pull_request]
jobs:
  structural:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sh examples/self-application/verify-consistency.sh
      - run: sh examples/schema-self-application/verify-schemas.sh
```

Enable branch protection on `main` and require this check.
That's it.

## What the workflow does

### Job 1: `structural` (required)

Runs the structural verifier and the schema meta-validator.
Exit 0 = convention holds. Exit 1 = violation, listed in logs.

### Job 2: `packet-count` (informational)

Reports the number of packets, theory docs, schemas, ADRs,
and examples. Posts as a comment on the PR.

### Job 3: `ignored-files` (informational)

Checks that `.gitignore` is present.

All jobs are independent. They run in parallel.

## Example workflow with TLA+ and TypeScript

For projects that use TLA+ and TypeScript, expand:

```yaml
name: verify
on: [push, pull_request]

jobs:
  structural:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sh examples/self-application/verify-consistency.sh
      - run: sh examples/schema-self-application/verify-schemas.sh

  tlc:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install TLC
        run: |
          wget -q https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar -O /tmp/tla2tools.jar
          echo "TLA2TOOLS_JAR=/tmp/tla2tools.jar" >> $GITHUB_ENV
      - name: Run TLC on all packets
        run: |
          for cfg in $(find . -name "Model.cfg" -not -path "*/.git/*"); do
              dir=$(dirname "$cfg")
              echo "Checking $cfg"
              (cd "$dir" && java -cp /tmp/tla2tools.jar tlc2.TLC -deadlock Model.cfg Model.tla 2>&1)
          done

  typescript:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npx tsc --noEmit
      - run: npx vitest run
```

Each job is independent: a TypeScript failure does not block
TLC, and vice versa. All required jobs must pass.

## Required checks

To block PRs that break the convention:

```
Repository Settings -> Branches -> main -> Require status checks
-> "verify / structural" (and any other required check)
```

Without branch protection, the verifier reports but does not
block. Branch protection is what turns verification into a
gate.

## Caching

TLC and tsc downloads are slow. Cache them:

```yaml
- name: Cache tla2tools
  uses: actions/cache@v4
  with:
    path: /tmp/tla2tools.jar
    key: tla2tools-v1.8.0
```

```yaml
- name: Cache node_modules
  uses: actions/cache@v4
  with:
    path: node_modules
    key: node-deps-${{ hashFiles('package-lock.json') }}
```

## Notifications

When the verifier fails on `main`, alert:

```yaml
- name: Notify on failure
  if: failure() && github.ref == 'refs/heads/main'
  run: |
    curl -X POST "$SLACK_WEBHOOK_URL" -d '{
      "text": "Verifier failed on main: ${{ github.event.head_commit.url }}"
    }'
```

## Matrix strategies

If you maintain multiple packets with different substrates,
use a matrix:

```yaml
jobs:
  verify-packet:
    strategy:
      matrix:
        packet: [modal-dialog, async-coordinator, ...]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sh examples/${{ matrix.packet }}/verify.sh
```

Each packet is verified independently; failures are isolated.

## Status badges

Add to `README/README.md`:

```markdown
![verify](https://github.com/USER/REPO/actions/workflows/verify.yml/badge.svg)
```

The badge is green when the last commit on `main` passed the
verifier; red otherwise. Users see at a glance whether the
convention is currently enforced.

## Anti-patterns

- **Caching the wrong files.** Cache what's slow and rarely
  changes. Don't cache `**`.
- **Running the verifier only on PR.** Run it on `push` to
  `main` as well — direct pushes to main should not break
  things silently.
- **Multiple verifiers in one job.** Each tool (TLC, tsc,
  pytest) should be its own job. Failures are easier to attribute.

## Setup

1. Push `.github/workflows/verify.yml` to your repository.
2. Enable branch protection on `main`.
3. Add the status badge to `README.md`.
4. Done. The convention is now enforced automatically.

## References

- GitHub Actions:
  <https://docs.github.com/en/actions>
- Status badges:
  <https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/adding-a-workflow-status-badge>