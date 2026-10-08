mathc validate exits 1 with a reject verdict for an unparseable
decision. The test invokes `mathc validate --format=json` and
projects the JSON object via `jq` to keep the assertion portable:
the `path` field is a project-relative path emitted by
`bin/Mathc.ml`'s JSON renderer, so it does not depend on the
machine's checkout location. Diagnostic fields (`code`,
`severity`, `message`) are projected as-is.

The `negative-empty-obligations.json` fixture intentionally
omits `axiom_link` and has `obligations: []`. Under the T2.2
rule (axiom_link required for active decisions) the
axiom-link check fires first and surfaces
`MC-AXIOM-LINK-MISSING` before the empty-obligations check
would have surfaced `MC-DECISION-INVALID`. The verdict is
still `reject` and the exit code is still 1.

  $ mathc validate --format=json "$DUNE_SOURCEROOT/fixtures/conformance/decision/negative-empty-obligations.json" | jq -c '{verdict, code, severity, message}'
  {"verdict":"reject","code":"MC-AXIOM-LINK-MISSING","severity":"block","message":"no-obligations: decision has state=active but empty axiom_link: spec/algebra-3.2.md §7 requires every active decision to name the axiom(s) it addresses via the axiom_link field; add one (e.g. axiom_link: [A0]) to the decision front-matter"}
