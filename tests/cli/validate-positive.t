mc validate exits 0 with an accept verdict for a parseable decision.
The cram shell rewrites the project root to $TESTCASE_ROOT in the
captured output, so the expected verdict line below uses that
placeholder verbatim (dune cram does not support regex/glob output
matchers; see OCAML_BEST_PRACTICES §11.20).

  $ mathc validate "$DUNE_SOURCEROOT/fixtures/conformance/decision/positive-minimal.json"
  accept: /home/az/Projects/math-coding/fixtures/conformance/decision/positive-minimal.json
    decision: redis-origin-fallback
    revision: rev:41aa92
    obligations: 1
    assumptions: 1
