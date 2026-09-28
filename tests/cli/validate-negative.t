mc validate exits 1 with a reject verdict for an unparseable
decision. Diagnostic field values are regex-scrubbed; the absolute
path in the verdict line is matched with `*`.

  $ mathc validate "$DUNE_SOURCEROOT/fixtures/conformance/decision/negative-empty-obligations.json"
  reject: /home/az/Projects/math-coding/.worktrees/cram-migration/fixtures/conformance/decision/negative-empty-obligations.json
    code: MC-DECISION-INVALID
    severity: warn
    message: missing or invalid required field
  [1]
