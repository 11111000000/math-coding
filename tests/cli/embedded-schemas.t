`mathc validate` works in a directory that has NO `schemas/`
subdirectory. The JSON schemas (`schemas/decision.json`,
`schemas/attestation.json`, `schemas/obligation.json`,
`schemas/waiver.json`, `schemas/policy.json`, `schemas/common.json`)
are now embedded as OCaml string constants in
`lib/schema_embedded.ml` (per `decisions/ux-3-minimal-pollution-2026-10.yaml`),
so a brownfield project that does not carry a `schemas/` tree still
gets full validation. PLAN.md §0.4 records this as the
"prune should drop `schemas/`" closure.

This is the surface test for that contract: pick a tmpdir with
neither `.math-coding/` nor `schemas/`, drop a JSON fixture in it,
run `mathc validate`, and assert accept verdict with the expected
exit code. The fixture used here is the same one
`tests/cli/validate-positive.t` validates successfully in the main
checkout, which proves the binary works without filesystem JSON
schemas just as well as with them.

  $ cd "$DUNE_SOURCEROOT"
  $ tmpdir=$(mktemp -d)
  $ cd "$tmpdir"

A brand-new tmpdir has neither `.math-coding/` nor `schemas/`.
Both must remain absent for the test to be a true embedded-schemas
test -- otherwise we would be testing the on-disk-schema path
and not the embedded path.

  $ test ! -d .math-coding && echo "no .math-coding/: ok"
  no .math-coding/: ok
  $ test ! -d schemas && echo "no schemas/: ok"
  no schemas/: ok

Copy the conformance fixture. We use the same fixture the existing
`tests/cli/validate-positive.t` exercises, so a behaviour drift in
the JSON-form parser trips both fixtures simultaneously.

  $ cp "$DUNE_SOURCEROOT/fixtures/conformance/decision/positive-minimal.json" test.json

Validate. The verdict is accept and exit code is 0 -- the same
verdict `tests/cli/validate-positive.t` expects when run against
the same fixture in the main checkout (where `schemas/` exists).
The test passing here proves the embedded-schemas path produces
the same verdict as the on-disk-schemas path.

  $ mathc validate test.json
  accept: test.json
    decision: redis-origin-fallback
    revision: rev:41aa92
    obligations: 1
    assumptions: 1

Run with --format=json to get the machine-readable verdict. The
verdict field MUST be "accept"; the exit code MUST be 0.

  $ mathc validate --format=json test.json
  {"verdict":"accept","path":"test.json","decision":"redis-origin-fallback","revision":"rev:41aa92","obligations":1,"assumptions":1}

Negative case: a malformed JSON document must STILL be rejected
the same way the on-disk-schemas path rejects it. The embedded
schema path is not a softer path. We hand-craft a fixture that
violates a required field and assert reject with exit code 1.

  $ cat > bad.json <<EOF
  > {
  >   "schema": "math-coding/3.0-alpha/decision",
  >   "kind": "decision",
  >   "id": "embedded-schemas-bad",
  >   "revision": "1",
  >   "state": "active",
  >   "mode": "standard",
  >   "axiom_link": ["A0"],
  >   "commitment": "no intent field",
  >   "counterexample": "no intent either",
  >   "scope": [{"kind": "path", "path": "lib/**"}],
  >   "outcomes": [{"id": "o", "statement": "s"}],
  >   "obligations": [{"id": "ob1", "acceptance": {"all": [{"verifier": "mathc self-check", "result": "pass"}]}}],
  >   "risk": {"declared_triggers": [], "owner": "human:maintainer"}
  > }
  > EOF
  $ mathc validate --format=json bad.json | jq -c '{verdict, code, severity}'
  {"verdict":"reject","code":"MC-DECISION-INVALID","severity":"warn"}
  $ if mathc validate bad.json > /dev/null 2>&1; then
  >   echo "FAIL: expected reject on missing intent"; exit 1
  > else
  >   echo "missing intent rejected (exit $?)"
  > fi
  missing intent rejected (exit 1)

Cleanup. The test never wrote to `.math-coding/` or `schemas/`,
so the host checkout is provably untouched.

  $ cd /
  $ rm -rf "$tmpdir"
  $ test ! -d "$tmpdir" && echo "tmpdir removed: ok"
  tmpdir removed: ok



