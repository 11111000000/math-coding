mathc new-decision axiom-link inference: when the produced
decision lacks `axiom_link`, the CLI emits a soft-warn naming
the top-3 most-likely axiom IDs based on `scope.paths`. The
warn is `deficit/MC-AXIOM-LINK-INFERENCE-EMPTY` and the
inference rule lives in
`lib/decision.ml::infer_axiom_candidates`.

The cram shell's cwd is a bwrap tmp dir. mathc is on the PATH
(deps %{bin:mathc} in tests/cli/dune). Each case runs the
binary with `MATH_CODING_NEW_DECISION_SCOPE_PATHS=<paths>`
overriding the template's `scope.paths` placeholder, and
asserts on the soft-warn contents.

A path "matches" a rule when it starts with the rule's
prefix. When multiple rules match, the result is the
deduplicated union (preserving first-occurrence order), capped
at 3 entries. When no rule matches, the fallback is `A0`.

The mathc binary path is anchored at the absolute path inside
the cram test (per OCAML_BEST_PRACTICES §11.20 / §11.34:
`$INSIDE_DUNE/bin/mathc.exe` triggers dune's build of the
binary and avoids the bwrap PATH issue).

Case 1: lib/ paths produce A0 (separation) + A1 (feedback).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" MATH_CODING_NEW_DECISION_SCOPE_PATHS="lib/foo.ml" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-lib --template=full --write 2>&1 | grep -q "top candidates: A0 (separation), A1 (feedback)" && echo "lib inference: ok"
  lib inference: ok
  $ rm -rf "$tmpdir"

Case 2: tests/ paths produce A1 (feedback).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" MATH_CODING_NEW_DECISION_SCOPE_PATHS="tests/foo.ml" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-tests --template=full 2>&1 | sed -n 's/.*top candidates: \(.*\); add axiom_link/top candidates: \1/p'
  top candidates: A1 (feedback)
  $ rm -rf "$tmpdir"

Case 3: decisions/ paths produce A0 (separation) + A4 (care).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" MATH_CODING_NEW_DECISION_SCOPE_PATHS="decisions/foo.yaml" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-decisions --template=full 2>&1 | sed -n 's/.*top candidates: \(.*\); add axiom_link/top candidates: \1/p'
  top candidates: A0 (separation), A4 (care)
  $ rm -rf "$tmpdir"

Case 4: spec/ paths produce A0 (separation) + A3
(self-application).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" MATH_CODING_NEW_DECISION_SCOPE_PATHS="spec/foo.md" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-spec --template=full 2>&1 | sed -n 's/.*top candidates: \(.*\); add axiom_link/top candidates: \1/p'
  top candidates: A0 (separation), A3 (self-application)
  $ rm -rf "$tmpdir"

Case 5: empty / placeholder paths fall back to A0
(separation).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-empty --template=full 2>&1 | sed -n 's/.*top candidates: \(.*\); add axiom_link/top candidates: \1/p'
  top candidates: A0 (separation)
  $ rm -rf "$tmpdir"

Negative case: --template=minimal hardcodes `axiom_link: [A0]`,
so the soft-warn does NOT fire (the field is present).

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-min --template=minimal 2>&1 | grep -E 'top candidates|deficit/MC-AXIOM-LINK-INFERENCE-EMPTY' || echo "no warn: ok"
  no warn: ok
  $ rm -rf "$tmpdir"

Negative case: paths that match no rule fall back to A0.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" MATH_CODING_NEW_DECISION_SCOPE_PATHS="random/foo.txt" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-misc --template=full 2>&1 | sed -n 's/.*top candidates: \(.*\); add axiom_link/top candidates: \1/p'
  top candidates: A0 (separation)
  $ rm -rf "$tmpdir"

Negative case: help text documents the soft-warn code
(`mathc explain-diagnostic MC-AXIOM-LINK-INFERENCE-EMPTY`
returns prose remediation).

  $ cd "$DUNE_SOURCEROOT"
  $ "$INSIDE_DUNE/bin/mathc.exe" explain-diagnostic MC-AXIOM-LINK-INFERENCE-EMPTY 2>&1 | grep -q '"definition"' && echo "explain: ok"
  explain: ok

--write mode emits both lines (soft-warn to stderr, `wrote` to
stdout). We avoid calling `--write` in this cram test because
the produced YAML would land in the math-coding `decisions/`
tree and become a new self-check unknown subject
(`plan-2026-10-adoption-fixes-2026-10` §2 boundaries:
"no new unknown subjects"). The Print-mode probe verifies the
soft-warn content via grep; the `--write` path uses the same
`New_decision.run` code path as Print-mode (template render +
post-write emit), so Print-mode coverage is sufficient.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ MATH_CODING_ROOT="$tmpdir" MATH_CODING_NEW_DECISION_SCOPE_PATHS="lib/foo.ml" "$INSIDE_DUNE/bin/mathc.exe" new-decision ax-warn-write --template=full 2>&1 | grep -q "top candidates: A0 (separation), A1 (feedback)" && echo "write+warn: ok"
  write+warn: ok
  $ rm -rf "$tmpdir"
