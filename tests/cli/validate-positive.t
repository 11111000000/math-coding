mathc validate exits 0 with an accept verdict for a parseable
decision. The test invokes `mathc validate --format=json` and
projects the JSON object via `jq` to keep the assertion portable:
the `path` field is a project-relative path emitted by
`bin/Mathc.ml`'s JSON renderer, so it does not depend on the
machine's checkout location. The cram shell invokes mathc with
`$DUNE_SOURCEROOT` (dune 3.23 export), so the test runs portably
in main, in worktrees, and on other machines.

  $ mathc validate --format=json "$DUNE_SOURCEROOT/fixtures/conformance/decision/positive-minimal.json" | jq -c '{verdict, decision, revision, obligations, assumptions}'
  {"verdict":"accept","decision":"redis-origin-fallback","revision":"rev:41aa92","obligations":1,"assumptions":1}
