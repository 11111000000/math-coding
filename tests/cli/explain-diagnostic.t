mathc explain-diagnostic resolves a registered `MC-*` code to a
JSON object carrying `code`, `definition`, `occurs_when`, and
`remediation`. The registry lives in `lib/diagnostic.ml::explain`
and covers the codes emitted by `bin/Mathc.ml:validate_with_counts`
plus the conformance runner. On an unknown code or a missing
positional argument the dispatcher prints a typed
`MC-EXPLAIN-DIAGNOSTIC-UNKNOWN` diagnostic on stderr and exits 2.

Acceptance gate for obligation `explain-diagnostic-cli-shipped` in
`decisions/plan-2026-10-improvements/t4-2.yaml`.

  $ cd "$DUNE_SOURCEROOT"

Positive case — known code MC-COUNTEREXAMPLE-MISSING exits 0 and
emits a JSON object with all four fields present and non-empty.
The fixture uses `jq` to project a stable shape (sorted keys are
preserved by the dispatcher per spec/semantics.md CLI output
contract):

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-COUNTEREXAMPLE-MISSING | jq -c '{code, def_len: (.definition | length), occ_len: (.occurs_when | length), rem_len: (.remediation | length)}'
  {"code":"MC-COUNTEREXAMPLE-MISSING","def_len":455,"occ_len":879,"rem_len":304}

Positive case — known code MC-AMBIGUOUS-ACCEPTANCE exits 0 with
the same shape contract. Confirms the registry is keyed by the
literal code string and the dispatcher returns the same envelope
for every registered code:

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-AMBIGUOUS-ACCEPTANCE | jq -c '{code, def_len: (.definition | length), occ_len: (.occurs_when | length), rem_len: (.remediation | length)}'
  {"code":"MC-AMBIGUOUS-ACCEPTANCE","def_len":101,"occ_len":227,"rem_len":113}

Negative case — unknown code MC-BOGUS exits 2 and prints a typed
diagnostic on stderr with code `MC-EXPLAIN-DIAGNOSTIC-UNKNOWN`.
The exit-code contract follows `mathc explain nonexistent:foo`
(tests/cli/explain-negative.t) — an input error is exit 2, not 1.
The supported-codes list rendered in the message is keyed off
`lib/diagnostic.ml::explain`; when a new `MC-*` code is registered
upstream, update the literal below to keep the test pinned to
the actual registry (last touched: `MC-VERIFIER-SCHEME-UNKNOWN`
added by `verifier-scheme-convention-2026-11`):

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-BOGUS
  {"code":"MC-EXPLAIN-DIAGNOSTIC-UNKNOWN","id":"MC-BOGUS","kind":"diagnostic","message":"unknown diagnostic code 'MC-BOGUS'; supported codes are listed by lib/diagnostic.ml::explain (MC-VERIFIER-SCHEME-UNKNOWN, MC-AMBIGUOUS-ACCEPTANCE, MC-MALFORMED-ACCEPTANCE, MC-PARSE, MC-DECISION-INVALID, MC-COUNTEREXAMPLE-MISSING, MC-AXIOM-LINK-MISSING, MC-SHA-MISMATCH)"}
  [2]

Negative case — missing positional argument exits 2 with a usage
hint. The dispatcher mirrors the `mathc explain` handler (see
`tests/cli/explain-negative.t` — the same exit-2 contract for a
missing positional):

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic
  mathc explain-diagnostic: missing CODE
  usage: mathc explain-diagnostic <CODE>
  [2]
