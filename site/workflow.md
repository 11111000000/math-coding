# Workflow

> **From intent to revision.** Math-coding workflow is the
> five-state FSM from `decisions/decision.yaml` applied
> as a discipline. Six steps, one binary.

![Lifecycle FSM of a single math-coding record: 7 states (draft, committed, implemented, attested, monitored, contested, retired), 6 main transitions, 4 block markers (violation, grace, stale, waiver-expiry).](assets/lifecycle-fsm.svg)

The diagram above is the workflow. Each of the six steps
below corresponds to one transition in the FSM: state
intent → commit → implement → attest → gate → self_verify
→ merge to main. The block markers (violation, grace, stale,
waiver-expiry) are the four conditions that can interrupt a
state and force a transition back to an earlier one.

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

The transition from `commit` to `implement` is gated by the
"every obligation has a positive + negative fixture" rule.
The obligation above has a positive acceptance clause
(`verifier: mathc packages --format=json, result: pass`);
a matching negative clause (a `result: fail` test that
asserts the verifier rejects a malformed decision) is added
in step 4 (Attest) before the `implement → attest` transition
becomes reachable.

## 3. Implement

`lib/packages.ml` and `bin/Mathc.ml` change to honour the
commitment. The implementation stays under OCaml and side-effect
free.

## 4. Attest

Produce the attestation for every package pair the kernel walks:
`attestations/<sha>.json`. The store is generated, not committed
(`decisions/store-not-committed-2026-10.yaml`); the release path is
`scripts/sign-store.sh`, and the live count is
`mathc counters --format=json`.

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

![Bootstrap timeline: v3-alpha-0.0.1 to 8fa7fcf (v3.0.0.19) to today. Manual regime ends at 8fa7fcf; automated regime begins the same commit.](assets/bootstrap-timeline.svg)

The bootstrap timeline above shows the same workflow applied
to the project itself. From `v3-alpha-0.0.1` to commit
`8fa7fcf` every transition was admitted by a human reviewer
(manual regime); from `8fa7fcf` onward, the kernel is the
admitter. The boundary between the two regimes is the
`mathc self-check` step in this workflow.

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
