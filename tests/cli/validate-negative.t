mc validate exits 1 with a reject verdict for an unparseable
decision. The test invokes `mc validate --format=json` and
projects the JSON object via `jq` to keep the assertion portable:
the `path` field is a project-relative path emitted by
`bin/Mathc.ml`'s JSON renderer, so it does not depend on the
machine's checkout location. Diagnostic fields (`code`,
`severity`, `message`) are projected as-is.

  $ mathc validate --format=json "$DUNE_SOURCEROOT/fixtures/conformance/decision/negative-empty-obligations.json" | jq -c '{verdict, code, severity, message}'
  {"verdict":"reject","code":"MC-DECISION-INVALID","severity":"warn","message":"missing or invalid required field"}
