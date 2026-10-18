mathc validate emits zero MC-VERIFIER-SCHEME-UNKNOWN diagnostics
when every obligation's acceptance carries ONLY canonical scheme
tokens: file-exists, dir-exists, bash, mathc, shell-grep, dune, plus
the documented prefixes text-scan-*, tests/, dune-*, scripts/,
manual-*. The decision parses-ok cleanly, no extra diagnostic
noise on stderr.

This is the negative pin for plan-decision C5 — the same surface
that fires when a scheme is non-canonical must remain silent when
the scheme IS canonical. Both directions of the convention are
covered.

  $ cd "$DUNE_SOURCEROOT"
  $ mathc validate fixtures/conformance/decision/positive-verifier-scheme-known.json
  parse-ok: fixtures/conformance/decision/positive-verifier-scheme-known.json
    decision: verifier-scheme-known-demo
    revision: rev:cafe01
    obligations: 1
    assumptions: 1

The stdout verdict carries no diagnostics array (empty extra_diags):

  $ mathc validate --format=json fixtures/conformance/decision/positive-verifier-scheme-known.json 2>/dev/null | jq -c '{verdict, has_diagnostics: has("diagnostics")}'
  {"verdict":"parse-ok","has_diagnostics":false}
