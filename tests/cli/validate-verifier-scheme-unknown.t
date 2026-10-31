mathc validate emits one Warn MC-VERIFIER-SCHEME-UNKNOWN diagnostic
per non-canonical verifier scheme token in
obligations[*].acceptance.all[*].verifier, while still printing
parse-ok on stdout and exiting 0. Severity is Warn (not Block) per
decisions/verifier-scheme-convention-2026-11.yaml.

This is the surface-emission pin for plan-decision C5 of
plan-2026-11-adoption-fixes-2026-10.

  $ cd "$DUNE_SOURCEROOT"

The full warning count is 4 (three on obligation
unknown-scheme-flagged-obligation, one on obligation
mixed-known-and-unknown-obligation). The verdict is still parse-ok.

  $ $INSIDE_DUNE/bin/mathc.exe validate fixtures/conformance/decision/positive-verifier-scheme-unknown.json
  [warn] input/MC-VERIFIER-SCHEME-UNKNOWN: obligation unknown-scheme-flagged-obligation: verifier scheme "mathc-foo-impl-runs-on-fixture" is not in the canonical list (file-exists, dir-exists, bash, mathc, shell-grep, shell-grep-absent, dune, text-scan-*, tests/*, dune-*, scripts/*, manual-*); convention documented in decisions/verifier-scheme-convention-2026-11.yaml
  [warn] input/MC-VERIFIER-SCHEME-UNKNOWN: obligation unknown-scheme-flagged-obligation: verifier scheme "binary-exists" is not in the canonical list (file-exists, dir-exists, bash, mathc, shell-grep, shell-grep-absent, dune, text-scan-*, tests/*, dune-*, scripts/*, manual-*); convention documented in decisions/verifier-scheme-convention-2026-11.yaml
  [warn] input/MC-VERIFIER-SCHEME-UNKNOWN: obligation unknown-scheme-flagged-obligation: verifier scheme "brew-tap-installed" is not in the canonical list (file-exists, dir-exists, bash, mathc, shell-grep, shell-grep-absent, dune, text-scan-*, tests/*, dune-*, scripts/*, manual-*); convention documented in decisions/verifier-scheme-convention-2026-11.yaml
  [warn] input/MC-VERIFIER-SCHEME-UNKNOWN: obligation mixed-known-and-unknown-obligation: verifier scheme "mathc-bogus-impl-runs" is not in the canonical list (file-exists, dir-exists, bash, mathc, shell-grep, shell-grep-absent, dune, text-scan-*, tests/*, dune-*, scripts/*, manual-*); convention documented in decisions/verifier-scheme-convention-2026-11.yaml
  parse-ok: fixtures/conformance/decision/positive-verifier-scheme-unknown.json
    decision: verifier-scheme-unknown-demo
    revision: rev:cafe02
    obligations: 2
    assumptions: 1

The canonical schemes in the same list (file-exists / mathc on the
second obligation) do NOT emit: the diagnostics above cover exactly
the four non-canonical tokens.

The JSON verdict envelope carries the diagnostics array (when not
empty):

  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json fixtures/conformance/decision/positive-verifier-scheme-unknown.json 2>/dev/null | jq -c '{verdict, codes: (.diagnostics // [] | map(.code) | unique), n_diags: (.diagnostics // [] | length)}'
  {"verdict":"parse-ok","codes":["MC-VERIFIER-SCHEME-UNKNOWN"],"n_diags":4}

mathc explain-diagnostic resolves the new code to its
three-section body (Definition, Occurs when, Remediation):

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-VERIFIER-SCHEME-UNKNOWN | jq -c '{code, def_len: (.definition | length), occ_len: (.occurs_when | length), rem_len: (.remediation | length)}'
  {"code":"MC-VERIFIER-SCHEME-UNKNOWN","def_len":486,"occ_len":778,"rem_len":632}

The unknown-code error path in mathc explain-diagnostic now lists
MC-VERIFIER-SCHEME-UNKNOWN in the supported-codes envelope:

  $ $INSIDE_DUNE/bin/mathc.exe explain-diagnostic MC-BOGUS 2>&1 | jq -rc .message
  unknown diagnostic code 'MC-BOGUS'; supported codes are listed by lib/diagnostic.ml::explain (MC-VERIFIER-SCHEME-UNKNOWN, MC-AMBIGUOUS-ACCEPTANCE, MC-MALFORMED-ACCEPTANCE, MC-PARSE, MC-DECISION-INVALID, MC-COUNTEREXAMPLE-MISSING, MC-AXIOM-LINK-MISSING, MC-SHA-MISMATCH)
