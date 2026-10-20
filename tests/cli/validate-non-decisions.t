mathc validate dispatches on the top-level `schema:` field
before the decision required-field check. Two non-decision
schema families live under `decisions/`: `math-coding/waiver-*`
(waivers in `decisions/waivers/`) and `math-coding/obligations-*`
(the obligations aggregator at `decisions/obligations.yaml`).
Both are well-formed for their own schema family but lack the
decision-required fields; without the dispatch, the decision
parser rejects them with `MC-DECISION-INVALID: missing required
field: <id|intent>` and the user has no way to validate them.
Per `decisions/mathc-validate-skip-non-decisions-fix-2026-10.yaml@1`.

  $ cd "$DUNE_SOURCEROOT"

A waiver file (schema: math-coding/waiver-*) accepts without
the decision parser running:

  $ mathc validate --format=json decisions/waivers/audit-0.0.21-fixes-self-check-verdict-is-pass-2026-10.yaml | jq -c '{verdict, kind, id}'
  {"verdict":"parse-ok","kind":"waiver","id":"audit-0.0.21-fixes-self-check-verdict-is-pass-2026-10"}

The obligations aggregator (schema: math-coding/obligations-*)
also accepts; the id is read from the nested `decision.id:`
field:

  $ mathc validate --format=json decisions/obligations.yaml | jq -c '{verdict, kind, id}'
  {"verdict":"parse-ok","kind":"obligations","id":"bootstrap-v3"}

A waiver file without `kind: waiver` does NOT take the fast
path (it falls through to the decision parser and rejects):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > waiver-without-kind.yaml <<EOF
  > ---
  > schema: math-coding/waiver-3.0-alpha
  > id: waiver-without-kind-demo
  > policy_id: bootstrap-v3
  > rule: obligation-missing-attestation
  > subject: audit-0.0.21-fixes
  > issuer: human:maintainer
  > issued_at: 2026-10-06T00:00:00Z
  > expires_at: 2027-04-06T00:00:00Z
  > reason: |
  >   The decision-parsed fast path is bypassed when the
  >   `kind: waiver` field is missing; the decision parser
  >   then rejects the file because the waiver schema is
  >   not a decision schema.
  > unverified_obligation: [some-obligation]
  > compensating_controls: [see revocation]
  > EOF
  $ mathc validate --format=json waiver-without-kind.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-DECISION-INVALID"}

A regular decision file still validates through the decision
path (regression: the decision parser is not weakened):

  $ cd "$DUNE_SOURCEROOT"
  $ mathc validate --format=json decisions/decision.yaml | jq -c '{verdict, kind}'
  {"verdict":"parse-ok","kind":"decision"}
  $ mathc validate --format=json decisions/algebra-3.2.yaml | jq -c '{verdict, kind}'
  {"verdict":"parse-ok","kind":"decision"}

Text-format output for a waiver file:

  $ mathc validate decisions/waivers/audit-0.0.21-fixes-self-check-verdict-is-pass-2026-10.yaml
  parse-ok: decisions/waivers/audit-0.0.21-fixes-self-check-verdict-is-pass-2026-10.yaml
    kind: waiver
    id: audit-0.0.21-fixes-self-check-verdict-is-pass-2026-10

A truncated YAML file still exits non-zero (the parser fails
before the dispatch):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > truncated.yaml <<EOF
  > ---
  > schema: math-coding/waiver-3.0-alpha
  > id: truncated-demo
  > EOF
  $ mathc validate --format=json truncated.yaml
  [1]
  $ cd /
  $ rm -rf "$tmp"