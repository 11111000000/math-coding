# TDD as an extension (v0.978)

math-coding does not require TDD. It does not forbid it.
It provides a *shape* for decisions; how those decisions
are verified is the project's choice.

If your target project uses TDD, this document shows the
explicit step-by-step workflow.

## The TDD workflow with math-coding

**Step 1. Create the packet (red).**

Write a spec that captures the proposition, outcome,
invariant, and test *before* writing code. The test is
expected to fail — you haven't written the implementation.

```yaml
proposition: |
  Cache entries expire after 60 seconds, not at user request.
outcome: |
  Cache returns fresh entry within 60s of last refresh.
invariant: |
  Cache entries never served beyond TTL.
test: |
  tests/cache-ttl.test.sh::test_stale_entry_refresh
  Insert entry with ts = now - 61s. Read. Expect upstream fetch.
antithesis: |
  The opposite — a manual invalidation endpoint — may be
  needed if a user explicitly wants fresh data now.
synthesis: |
  TTL is fixed at 60s; manual invalidation is a separate
  endpoint. The two paths are independent.
operation: |
  On read, check entry timestamp. If age > 60s, refresh
  from upstream.
```

Run:
```
sh math-coding create cache-ttl --from /tmp/spec.yaml
```

**Step 2. Write the test (red).**

Create a test file (e.g. *tests/cache-ttl.test.sh*) with
the test from the spec.

Run it. Expect FAIL. The packet exists but the test fails
because the implementation does not yet exist.

**Step 3. Implement the code (green).**

Write the implementation file (e.g. *src/cache.py*, or
whatever the operation specifies).

Run the test. Expect PASS. The test now passes because
the implementation matches the proposition.

**Step 4. Commit.**

```
git add math/cache-ttl/ src/cache.py tests/cache-ttl.test.sh
git commit -m "cache-ttl: 60s TTL implementation"
```

**Step 5. Apply.**

```
sh math-coding apply cache-ttl
```

This records the SHA of the commit in `applications[]` and
transitions the packet from `draft` to `applied`. verify
runs automatically.

**Step 6. Add `tests:` to applications[].**

After apply, edit the new packet's YAML (e.g.
*math/cache-ttl/packet.yaml*) and add `tests:` to the
applications entry:

```yaml
applications:
  - sha: abc123def456
    by: agent
    date: "2026-07-16"
    pressure: feature
    files:
      - src/cache.py
      - tests/cache-ttl.test.sh
    tests: "sh tests/cache-ttl.test.sh"
    tests_result: PASS
```

Or re-run `apply` with `--tests=`:

```
sh math-coding apply cache-ttl --tests="sh tests/cache-ttl.test.sh"
```

**Step 7. CI runs the recorded tests.**

Run the recorded tests in your project's CI workflow.
A template is in `extensions/ci/github-actions-tdd.yml`.

## What math-coding sees, what it does not

The convention sees:

- `refinement.md:test` — natural-language description of
  the test.
- `applications[].tests` (optional) — a command string
  recorded as part of the SHA witness.

The convention does NOT:

- Run the command.
- Track test history across SHAs.
- Compare test results between commits.

Running the test is the responsibility of the target
project's CI. The convention records that the test
*exists* and was *claimed* to pass; the CI proves it.

## What this is NOT

- **Not a runner.** math-coding does not invoke pytest,
  jest, go test, cargo test, bats, or any other test
  framework. The convention's runtime is POSIX shell.

- **Not a coverage tool.** math-coding does not measure
  how much of `refinement.md:operation` is covered by
  `refinement.md:test`.

- **Not a CI template.** This extension documents the
  shape; the actual `.github/workflows/<name>.yml` (or
  equivalent) is the project's responsibility.

## Optional CI template

See `extensions/ci/github-actions-tdd.yml` for a template
GitHub Actions workflow.

## What if my project doesn't use TDD?

Omit `applications[].tests` and `applications[].tests_result`.
The packet can still move to `applied`. verify checks
structure, not test execution.

The convention is shape, not practice. TDD is one of many
practices that fit the shape. Choose the one that fits
your project.