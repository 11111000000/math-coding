# Workflow

> **From intent to revision.** Math-coding workflow is the
> five-state FSM from `decisions/decision.yaml` applied
> as a discipline. Six steps, one binary.

## 1. State intent

Open a `decisions/<id>.yaml` with `intent:`. The intent is
the *why*; the *commitment* comes next. A record without
intent is a record about nothing.

```yaml
intent: |
  Add a structured log of decision-obligation verdicts so
  reviewers can answer "is this safe to merge?" without
  re-reading the kernel.
```

## 2. Commit

The commitment is the **falsifiable claim**. The
`obligation` block names the verification:

```yaml
commitment: |
  mathc packages --format=html renders an HTML grid of
  decision-obligation pairs with verdicts.
obligation:
  - id: packages-kernel-walker
    acceptance:
      all:
        - verifier: mathc packages --format=json
          result: pass
```

## 3. Implement

`lib/packages.ml` and `bin/Mathc.ml` change to honour the
commitment. The implementation stays under OCaml, side-effect
free, ~700 lines plus the binary.

## 4. Attest

Run `scripts/generate-attestations.py` after each
implementation. The script produces
`attestations/<sha>.json` for every package pair. Commit
the JSON files.

## 5. Gate

`mathc gate BASE HEAD` runs against the populated store.
The exit code is `0` for `pass`, `1` for `block`,
`3` for `unknown`. The CI block step is `mathc self-check`.

## 6. Self-verify

`mathc self-check` runs against the **entire** decision
graph. Its exit code gates merge to `main`. The
self-check's JSON carries `verdict`, `subjects_count`,
`pass_count`, and the `kernel_digest` (SHA-256 of the
binary that produced the verdict).

## A worked example

A decision to add `mathc packages` went through the six
steps in commit `5d1046a`:

| Step | Commit | Verifier |
|------|--------|----------|
| 1. State intent | `mathc-packages-subcommand@1` | `intent:` block |
| 2. Commit | same | `commitment:` + `obligation:` |
| 3. Implement | `lib/packages.ml`, `bin/Mathc.ml` | `dune build` exits 0 |
| 4. Attest | `attestations/mathc-packages-subcommand-*.json` | `mathc packages --format=json` |
| 5. Gate | `tests/cli/gate-{pass,fail,stale}.t` | cram green |
| 6. Self-verify | `tests/cli/self-check-pass.t` | cram green |

The six-step loop is the kernel applying A3 to itself.
[Axioms](axioms.html) for the formal statement.