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
the decision parser running. The corpus carries no waivers at the
moment -- the 98 that the census wrote were machine-signed dossiers
and they are gone -- so the file is planted here: the SCHEMA FAMILY
is what this test is about, and a family that has no member left in
the corpus would otherwise go untested.

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > waiver-demo.yaml <<'EOF'
  > ---
  > schema: math-coding/waiver-3.0-alpha
  > kind: waiver
  > id: waiver-family-demo
  > policy_id: bootstrap-v3
  > rule: obligation-missing-attestation
  > subject: audit-0.0.21-fixes
  > issuer: human:maintainer
  > issued_at: 2026-10-06T00:00:00Z
  > expires_at: 2027-04-06T00:00:00Z
  > reason: |
  >   A waiver states who accepted which gap, until when.
  > unverified_obligation: [some-obligation]
  > compensating_controls: [see revocation]
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json waiver-demo.yaml | jq -c '{verdict, kind, id}'
  {"verdict":"parse-ok","kind":"waiver","id":"waiver-family-demo"}
  $ cd "$DUNE_SOURCEROOT"

The obligations aggregator (schema: math-coding/obligations-*)
also accepts; the id is read from the nested `decision.id:`
field:

  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json decisions/obligations.yaml | jq -c '{verdict, kind, id}'
  {"verdict":"parse-ok","kind":"obligations","id":"bootstrap-v3"}

A waiver file without `kind: waiver` does NOT take the fast
path (it falls through to the decision parser and rejects):

  $ tmp2=$(mktemp -d)
  $ cd "$tmp2"
  $ cat > waiver-without-kind.yaml <<'EOF'
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
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json waiver-without-kind.yaml | jq -c '{verdict, code}'
  {"verdict":"reject","code":"MC-DECISION-INVALID"}

A regular decision file still validates through the decision
path (regression: the decision parser is not weakened). The
decision JSON shape carries `decision`/`revision`/`obligations`,
not the aggregate family's `kind`/`id` pair; stderr carries
per-obligation verifier-scheme warnings for these files and is
not part of this projection:

  $ cd "$DUNE_SOURCEROOT"
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json decisions/decision.yaml 2>/dev/null | jq -c '{verdict, decision, has_obligations: (.obligations > 0)}'
  {"verdict":"parse-ok","decision":"bootstrap-v3","has_obligations":true}
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json decisions/algebra-3.2.yaml 2>/dev/null | jq -c '{verdict, decision, has_obligations: (.obligations > 0)}'
  {"verdict":"parse-ok","decision":"algebra-3.2","has_obligations":true}

Text-format output for a waiver file -- the same planted file, read
the other way:

  $ $INSIDE_DUNE/bin/mathc.exe validate "$tmp/waiver-demo.yaml" | sed "s|$tmp|<TMP>|g"
  parse-ok: <TMP>/waiver-demo.yaml
    kind: waiver
    id: waiver-family-demo

A truncated YAML file still exits non-zero (the parser fails
before the dispatch):

  $ tmp=$(mktemp -d)
  $ cd "$tmp"
  $ cat > truncated.yaml <<EOF
  > ---
  > schema: math-coding/waiver-3.0-alpha
  > id: truncated-demo
  > EOF
  $ $INSIDE_DUNE/bin/mathc.exe validate --format=json truncated.yaml
  {"verdict":"reject","path":"truncated.yaml","code":"MC-DECISION-INVALID","severity":"warn","message":"missing required field: intent"}
  [1]
  $ cd /
  $ rm -rf "$tmp"
