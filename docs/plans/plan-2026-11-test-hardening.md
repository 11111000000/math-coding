# plan-2026-11-test-hardening — make the cram suite mean something

Status: plan only. No fixture expectation is edited by this document.

Measured at `a3e4f09` + `390561b` (main, 2026-10-20). Reproduce with:

```sh
nix develop .#test --command bash -c \
  "dune build @install >/dev/null 2>&1; dune test --force tests/cli/"
```

**39 red `tests/cli/*.t` fixtures**, down from 51 before
`kernel-fixes-found-bugs-2026-10@1`.

## The number is not yet trustworthy (W0 — blocking)

Before planning fixes, one fact has to be established: whether a red
fixture means "the kernel disagrees with the fixture".

It currently does not. `dune test` runs **some** fixtures against a
stale `mathc`, and which ones it picks is not explainable from the
file's content:

- `tests/cli/init-defaults.t` expects the applicability envelope that
  `mathc init` prints; under `dune test` the actual output omits it.
  Running the same binary directly prints it.
- Copying the file to a new name (`zz-copy-of-gate-pass.t`) makes it
  pass, in the **same** `dune test` invocation as the failing original.
- Neither `dune build @install` nor `dune test --force` repairs it.

Reproducer, minimal:

```sh
cp tests/cli/gate-pass.t tests/cli/zz-copy.t
dune test tests/cli/gate-pass.t tests/cli/zz-copy.t   # original 0, copy 672
```

Consequences to accept before anything else is attempted:

1. The "39 red" headline is a lower bound with an unknown error bar.
2. Fixing W1–W5 against a measurement that can silently lie risks
   editing expectations to match a binary that is not the shipped one.

**Exit criterion**: two consecutive full runs on an unchanged tree
produce byte-identical failure sets, and every fixture that asserts a
number produced by the binary is re-measured afterwards.

Candidate causes to check first, cheapest first: dune's runtest cache
keyed on the wrong digest (`rm -rf _build/.cache`), `@default` vs
`@install` divergence for `%{bin:mathc}` (two `mathc*` targets in
`bin/`), and the `(cram)` stanza's dep list.

## Composition of the red set

| Class | Count | Nature |
|---|---|---|
| C/E behaviour change needing judgement | 29 | may be regressions |
| B count drift after repo growth | 7 | mechanically fixable, but wrong to keep asserting live counts |
| D literal `/tmp/nix-shell.*` or `(glob)` in expectation | 2 | path hygiene |
| A verdict rename residue | 1 | should have been zero |

## W1 — stop asserting live repository counts (7 fixtures)

`gate-fail.t`, `gate-empty.t`, `gate-pass.t`, `gate-stale.t`,
`gate-unknown-exit-3.t`, `gate-v32-wired.t`, `required-attestation.t`
all assert `obligations: 183` / `184`. The repository now holds 672.
The same shape appears in `self-check-pass.t` (subjects 150 → 199),
`self-check-unknown.t`, `precommit.t` (127 → 200 files),
`migration-3.2-fields.t` (48 → 197), `migrate-bump-replay.t`.

These numbers were never a property of the code under test; they were
a property of *the day the fixture was written*. Every new decision
file breaks them, which is the mechanical reason the suite rotted in
the first place.

Replace exact counts with relational assertions
(`obligations > 0`, `gaps_count == obligations - passed`, verdict
transitions) or point them at a frozen fixture tree that does not
grow.

## W2 — behaviour drift that may be a real regression (read the code, do not promote)

Highest value, highest effort. Each needs the implementing module read
before the expectation is touched.

- `mcp.t` — `mathc/validate` no longer surfaces
  `MC-ANTITHESIS-MISSING`, and the unknown-method diagnostic changed.
  **A lost diagnostic is the single most likely real regression in the
  set.** Start here.
- `mode.t` — `mode: standard → tiny` for risk 0.025. §2 buckets say
  `tiny if r < 0.05`, so the kernel looks right and the fixture looks
  stale; but something changed. Read `lib/risk.ml` history before
  concluding.
- `doctor.t` — `[decisions] pass → warn`. Same shape of question.
- `env-var-resolver.t` — a new
  `deficit/MC-AXIOM-LINK-INFERENCE-EMPTY` warning appeared.
- `counters-schema-introspection.t` — `schema.decision_required_fields`
  is no longer a 7-element array.
- `risk-bucketing.t` — spec line-number pins (112 → 123) plus the
  mode change above.
- `gate-axiom-commit.t` — `block → unknown`.

## W3 — path hygiene (2 fixtures)

`new-decision.t` uses `(glob)`, which dune 3.23.1's vendored cram does
not implement (8 expected lines → 51 actual). `adopt-real-arc42.t`
bakes `/tmp/nix-shell.XYM15B/...` into its expectations. Both are
solved by the treatment `init.t` received: `cd` into a fresh
`mktemp -d`, act on `.`, assert with greps.

## W4 — mechanical pins (3–5 fixtures)

`version.t` (`3.1.0-alpha-final` → `3.3.3`), `update.t`
(`3.3.0` → `3.3.3`), `applicability-envelope.t` (a `grep -c 'Tier 3.5'`
count of 4 → 3), `verify.t` (usage text), `explain-diagnostic.t`
(message text), `decision-state.t` (a verdict string the parse-ok
sweep missed).

## W5 — repo hygiene the suite already flags

- `quickstart-md-exists.t` — `QUICKSTART.md` is 113 lines against the
  repo's own 100-line rule. Either trim the document or amend the
  rule; deciding which is the work, and the decision belongs in the
  cycle that does it.
- `install.t` (36/49-line diffs), `install-docker-fallback.t` — these
  execute `scripts/install-tooling/install.sh`, which was committed
  mode 100644 until this cycle. They moved from exit 126 to real
  output; both need re-reading, not promoting.

## W6 — two dune infra errors, not test failures

`tests/scripts/generate-attestations-env.t` and
`tests/scripts/release-cosign-blob.t` fail with
`Could not access ... .corrected`. They appear only when the whole
`tests/` subtree is selected, not under `tests/cli/`. Track separately
or exclude; they say nothing about the kernel.

## Standing rules proposed at the end of W0

1. A grep-based check (fits `scripts/check.sh`) that no
   `tests/cli/*.t` contains `/tmp/nix-shell` or `(glob)`.
2. No fixture asserts a count produced by the live repository, unless
   the count is normalised to a ratio or bounded by a predicate.
3. `tests/cli/*.t` heredocs use a quoted delimiter (`<<'EOF'`). One
   fixture lost its failure mode to a backticked `` `mode: considered` ``
   that the shell executed.

## Order

W0 → W1 → W3 + W4 (both mechanical) → W2 → W5 → W6.

W2 is last on purpose: it is the only batch where editing an
expectation can hide a defect rather than expose one, and it needs
W0's stable measurement to be trustworthy at all.