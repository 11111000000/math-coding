mathc re-evaluate classifies a (DECISION_ID, AXIOM_ID) pair per
algebra 3.2 §17 (T1.2 expansion: 4+1-valued status). Exercises
the rejection paths and the new no-run Incompatible verdict.

For a decision whose verifier is `tests/cli/<name>.t`, calling
`mathc re-evaluate` without an explicit `mathc
re-evaluate-decisions` run MUST return verdict `incompatible`
per obligation (T1.2 A1 closure: a `Compatible` verdict requires
an explicit run). The positive `compatible_after_run` verdict
is asserted in tests/cli/re-evaluate-decisions.t.

Acceptance gate for obligation re-evaluate-subcommand-spec-row
in decisions/3-2-cli-catalog.yaml.

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate
  mathc re-evaluate: DECISION_ID and AXIOM_ID are required
  [2]
  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate nonexistent A1
  mathc re-evaluate: unknown DECISION_ID nonexistent
  [2]
  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate bootstrap-v3 BOGUS
  mathc re-evaluate: AXIOM_ID must be one of A0..A4 (got BOGUS)
  [2]

T1.2 dual-failure evidence (negative): a decision whose
acceptance verifier is `tests/cli/<name>.t` returns
`incompatible` per obligation when no run has been performed.
3-2-cli-catalog has seven such verifiers (`tests/cli/mode.t`,
`tests/cli/rebuttals.t`, `tests/cli/re-evaluate.t`, their
fixture-pair siblings, and the `tests/fixtures/3-2-cli-catalog-rows-present.sh`
row check the corpus rewrite added), so the no-run verdict is
`incompatible`.

  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate 3-2-cli-catalog A0 | jq -r '.verdict, .ran'
  incompatible
  false
  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate 3-2-cli-catalog A0 | jq -r '[.obligations[] | select(.verdict == "incompatible")] | length'
  7

T1.2 positive (built-in verifier still `Compatible` without
run): a decision whose only `mathc-`-prefixed verifier maps to
`BuiltIn` and is therefore still `Compatible` even without an
explicit run (`mathc-self-check-verdict` is a built-in kernel
verifier).

The corpus does not carry such an obligation any more: the corpus
rewrite folded the old `kernel-unchanged` obligation of
`algebra-3.2-notation-flag-2026-10` away, and every `mathc-`
verifier that is left sits BEHIND a `tests/...` one in its own
acceptance list, which makes that obligation test-style (the
classification reads the FIRST verifier of the list). The
contract is the KERNEL's classification of a built-in verifier,
so the case is pinned against a scratch decision rather than
against whichever corpus decision happens to hold one today.

  $ tmp=$(mktemp -d)
  $ touch "$tmp/dune-project"
  $ mkdir -p "$tmp/decisions"
  $ cat > "$tmp/decisions/builtin-verifier.yaml" <<'YAML'
  > ---
  > schema: math-coding/3.3
  > id: re-evaluate-builtin-verifier
  > revision: 1
  > state: active
  > mode: light
  > body_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > yaml_sha: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  > intent: |
  >   Scratch decision for the built-in verifier classification.
  > commitment: |
  >   One obligation, one kernel built-in verifier.
  > axiom_link:
  >   - A0
  > scope:
  >   paths:
  >     - "tests/cli/re-evaluate.t"
  > outcomes:
  >   - id: o1
  >     statement: trivially true.
  > obligations:
  >   - id: kernel-unchanged
  >     outcome: o1
  >     claim: The kernel built-in verifier is invocable in-process.
  >     acceptance:
  >       all:
  >         - verifier: mathc-self-check-verdict-pass
  >           result: pass
  > counterexample: |
  >   None -- synthetic.
  > risk:
  >   declared_triggers: []
  >   owner: human:maintainer
  > YAML
  $ MATH_CODING_ROOT="$tmp" $INSIDE_DUNE/bin/mathc.exe re-evaluate re-evaluate-builtin-verifier A0 | jq -r '.obligations[] | select(.id == "kernel-unchanged") | .verdict'
  compatible

T1.2 manual-style verifier still maps to `inconclusive`: the
`notation-note-present` obligation has a non-built-in verifier
(`rg -n '...' spec/algebra-3.2.md`); without a run the verdict
is `inconclusive` (does not block; surfaces follow-up review).

  $ $INSIDE_DUNE/bin/mathc.exe re-evaluate algebra-3.2-notation-flag-2026-10 A0 | jq -r '.obligations[] | select(.id == "notation-note-present") | .verdict'
  inconclusive
